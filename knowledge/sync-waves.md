# ArgoCD Sync Wave Documentation

This is to document the various resources, their ordering, and their dependencies that are synced via ArgoCD sync waves into the homelab cluster.

The resources in the cluster are applied in three tiers of sync waves from the root configuration down to individual application workloads.

* **Tier 0 (Root):** These are the root-level ArgoCD `Application` and `AppProject` manifests that define the structure of the cluster. They control the order in which ArgoCD discovers and recursively applies the rest of the repository.

* **Tier 1 (Infrastructure):** This is critical cluster infrastructure, that is, everything that all other cluster workloads need to run. This tier is essential to get the cluster into a working and debuggable state.

* **Tier 2 (Applications):** This is for application workloads that depend on everything or most of what is deployed in tier 1.

# Sync Waves

## Tier 0: Root Bootstrap

### Wave -1
* **ArgoCD Projects** ([`projects.yaml`](/k8s/app-of-apps/projects.yaml)):

  * **Purpose:** Configures the logical `AppProject` boundaries, permissions, and target namespaces inside ArgoCD before any applications are deployed.

  * **Dependencies:** none

### Wave 1
* **Infrastructure Root** ([`infra.yaml`](/k8s/app-of-apps/infra.yaml)):

  * **Purpose:** The root ArgoCD Application that tells the cluster where to find and start deploying infrastructure workloads.

  * **Dependencies:** ArgoCD Projects (Wave -1)

### Wave 2
* **Applications Root** ([`apps.yaml`](/k8s/app-of-apps/apps.yaml)):

  * **Purpose:** The root ArgoCD Application that tells the cluster where to find and start deploying application workloads.

  * **Dependencies:** Infrastructure Root (Wave 1)

## Tier 1: Infrastructure

These resources are managed recursively under the infra.yaml root application.

### Wave -11
* **Victoria Logs Collector** ([`vlogs-collector.yaml`](/k8s/app-of-apps/infra/addons/vlogs-collector.yaml)):

  * **Purpose:** provides log collection across the entire cluster

  * **Dependencies:** none

* **Prometheus Node Exporter** ([`node-exporter.yaml`](/k8s/app-of-apps/infra/addons/node-exporter.yaml)):

  * **Purpose:** provides metric collection across the entire cluster

  * **Dependencies:** none

* **Envoy Gateway CRDs** ([`envoy-gateway.yaml`](/k8s/app-of-apps/infra/addons/envoy-gateway.yaml)):

  * **Purpose:** provides the CRDs needed by Envoy Gateway. Present due to GatewayAPI CRDs being expected to exist already within the cluster at bootstrap time.

  * **Dependencies:** none

### Wave -10
* **Envoy Gateway Controller** ([`envoy-gateway.yaml`](/k8s/app-of-apps/infra/addons/envoy-gateway.yaml)):

  * **Purpose:** Deploys the core Envoy Gateway control plane components.

  * **Dependencies:** Envoy Gateway CRDs (Wave -11)

* **Cert Manager** ([`cert-manager.yaml`](/k8s/app-of-apps/infra/addons/cert-manager.yaml)):

  * **Purpose:** Automated TLS certificate management and provisioning.

  * **Dependencies:** none

* **External Secrets Operator** ([`external-secrets.yaml`](/k8s/app-of-apps/infra/addons/external-secrets.yaml)):

  * **Purpose:** Syncs secrets from external managers into native Kubernetes secrets.

  * **Dependencies:** none

* **CloudNative-PG Operator** ([`cloudnative-pg.yaml`](/k8s/app-of-apps/infra/addons/cloudnative-pg.yaml)):

  * **Purpose:** Database operator for managing highly available PostgreSQL clusters.

  * **Dependencies:** none

* **KEDA** ([`keda.yaml`](/k8s/app-of-apps/infra/addons/keda.yaml)):

  * **Purpose:** Kubernetes Event-driven Autoscaling components.

  * **Dependencies:** none

### Wave -9
* **Victoria Metrics Operator** ([`vm-operator.yaml`](/k8s/app-of-apps/infra/addons/vm-operator.yaml)):

  * **Purpose:** Manages VictoriaMetrics components like VMAgent and VMSingle.

  * **Dependencies:** Cert-Manager (Wave -10)

* **Barman Cloud** ([`barman-cloud.yaml`](/k8s/app-of-apps/infra/addons/barman-cloud.yaml)):

  * **Purpose:** Cloud backup utilities for CloudNative-PG managed databases.

  * **Dependencies:** CloudNative-PG Operator (Wave -10)

### Wave -8
* **Victoria Metrics Stack** ([`victoria-metrics-stack.yaml`](/k8s/app-of-apps/infra/addons/victoria-metrics-stack.yaml)):

  * **Purpose:** Core monitoring, metric collection, and alerting components.

  * **Dependencies:** Victoria Metrics Operator (Wave -9)

* **Victoria Logs** ([`victoria-logs.yaml`](/k8s/app-of-apps/infra/addons/victoria-logs.yaml)):

  * **Purpose:** Central backend engine for log storage and aggregation.

  * **Dependencies:** Victoria Logs Collector (Wave -11)

### Wave -7
* **Cluster Secret Store** ([`cluster-secret-store.yaml`](/k8s/app-of-apps/infra/configuration/networking/dns-tls/cluster-secret-store.yaml)):

  * **Purpose:** Cluster-wide configuration linking the External Secrets Operator to the external backend (in this case Infisical).

  * **Dependencies:** External Secrets Operator (Wave -10)

### Wave -6
* **Cert Manager Secret** ([`certmanager-secret.yaml`](/k8s/app-of-apps/infra/configuration/networking/dns-tls/certmanager-secret.yaml)):

  * **Purpose:** Stores DNS provider credentials needed for ACME DNS-01 challenges.

  * **Dependencies:** External Secrets / Cluster Secret Store (Wave -7)

* **ExternalDNS Secret** ([`externaldns-dns-secret.yaml`](/k8s/app-of-apps/infra/configuration/networking/dns-tls/externaldns-secret.yaml)):

  * **Purpose:** Stores cloud provider API credentials for DNS subdomain creation and updates.

  * **Dependencies:** External Secrets / Cluster Secret Store (Wave -7)

### Wave -5
* **External DNS** ([`external-dns.yaml`](/k8s/app-of-apps/infra/addons/external-dns.yaml)):

  * **Purpose:** Automatically configures DNS records based on Gateway API configurations.

  * **Dependencies:** ExternalDNS Secret (Wave -6)

* **Cluster Issuer** ([`cluster-issuer.yaml`](/k8s/app-of-apps/infra/configuration/networking/dns-tls/cluster-issuer.yaml)):

  * **Purpose:** Cluster-wide Let's Encrypt issuer configuration for automated certs.

  * **Dependencies:** Cert Manager Secret (Wave -6)

### Wave -4
* **External Cluster Gateway** ([`cluster-gateway.yaml`](/k8s/app-of-apps/infra/configuration/networking/gateways/cluster-gateway.yaml)):

  * **Purpose:** Gateway configuring external public access to workloads within the cluster.

  * **Dependencies:** Cluster Issuer (Wave -5)

  * **Internal wave breakdown:**
    * `Namespace/gateway-system` — Wave -4
    * `Gateway/external-gateway` — Wave -3

### Wave -3
* **Tailscale Gateway** ([`tailscale-gateway.yaml`](/k8s/app-of-apps/infra/configuration/networking/gateways/tailscale-gateway.yaml)):

  * **Purpose:** Gateway configuring external private access to workloads within the cluster. Only identities allowed on the configured private tailnet can access this gateway.

  * **Dependencies:**
    * Envoy Gateway Controller / CRDs (Wave -10)
    * Cluster Issuer (Wave -5)

  * **Internal wave breakdown:**
    * `EnvoyProxy/management-gateway-proxy` — Wave -3
    * `GatewayClass/tailscale` — Wave -2
    * `Gateway/management-gateway` — Wave -1

## Tier 2: Applications

These resources are managed recursively under the apps.yaml root application.

### Wave -7
* **Zitadel Namespace** ([`namespace.yaml`](/k8s/app-of-apps/apps/zitadel/namespace.yaml)):

  * **Purpose:** namespace for Zitadel

  * **Dependencies:** none

### Wave -6
* **Zitadel Master Key Secret** ([`master-key.yaml`](/k8s/app-of-apps/apps/zitadel/master-key.yaml)):

  * **Purpose:** provides master cryptographic key used to encrypt the Zitadel database.

  * **Dependencies:** Zitadel Namespace (Wave -7) / External Secrets Operator (Tier 1, Wave -10)

### Wave -5
* **Zitadel Backup Keys** ([`backup-keys.yaml`](/k8s/app-of-apps/apps/zitadel/backups/backup-keys.yaml)):

  * **Purpose:** provides credentials needed to access external block storage for barman to perform periodic backups of the Zitadel database.

  * **Dependencies:** Zitadel Namespace (Wave -7) / External Secrets Operator (Tier 1, Wave -10)

### Wave -3
* **Zitadel Database Cluster** ([`db.yaml`](/k8s/app-of-apps/apps/zitadel/db.yaml)):

  * **Purpose:** Sets up the CNPG database cluster used by Zitadel.

  * **Dependencies:** Zitadel Namespace (Wave -7), CloudNative-PG Operator (Tier 1, Wave -10)

### Wave -2
* **Zitadel Database Credentials** ([`db-credentials.yaml`](/k8s/app-of-apps/apps/zitadel/db-credentials.yaml)):

  * **Purpose:** periodically rotates CNPG default credentials for security

  * **Dependencies:** Zitadel Database Cluster (Wave -3) / / External Secrets Operator (Tier 1, Wave -10)

### Wave 0
* **Zitadel Application Runtime** ([`app.yaml`](/k8s/app-of-apps/apps/zitadel/app.yaml)):

  * **Purpose:** The actual deployment and service engine for Zitadel.

  * **Dependencies:** Zitadel Database Credentials (Wave -2), Zitadel Master Key (Wave -6)

* **Zitadel Backup Store** ([`backup-store.yaml`](/k8s/app-of-apps/apps/zitadel/backups/backup-store.yaml)):

  * **Purpose:** Attaches the ongoing automated snapshot backup tasks to persistent storage.

  * **Dependencies:** Zitadel Backup Keys (Wave -5)