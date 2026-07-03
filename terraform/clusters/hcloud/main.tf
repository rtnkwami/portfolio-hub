module "talos_k8s" {
  source = "./talos-k8s"

  hcloud_token = var.hcloud_token
  project_name = "homelab"

  talosconfig_path = "${path.module}/outputs/talosconfig"
  kubeconfig_path  = "${path.module}/outputs/kubeconfig"
  nodepools        = local.nodepools

  tailscale_client_id = var.tailscale_client_id
  tailscale_client_secret = var.tailscale_client_secret
}

# Infisical is used as the external secret store for the cluster
resource "kubernetes_namespace_v1" "external_secrets" {
  metadata {
    name = "external-secrets"
  }

  depends_on = [module.talos_k8s]
}

resource "kubernetes_secret_v1" "infisical_creds" {
  metadata {
    name      = "infisical-credentials"
    namespace = kubernetes_namespace_v1.external_secrets.metadata[0].name
  }

  data_wo = {
    clientId     = var.infisical_client_id
    clientSecret = var.infisical_client_secret
  }
  data_wo_revision = 1
  immutable        = true
}

resource "tailscale_acl" "this" {
  overwrite_existing_content = true
  acl = jsonencode({
    tagOwners = {
      "tag:k8s-operator" = ["autogroup:admin"]
      "tag:k8s" = ["tag:k8s-operator"]
      "tag:k8s-admin" = ["autogroup:admin"]
    }
    autoApprovers = {
      services = {
        "tag:k8s" = ["tag:k8s"]
        "svc:*" = ["tag:k8s"]
      }
    }
    grants = [
      # Allow only k8s admins to access the k8s API proxy
      {
        src = ["tag:k8s-admin"]
        dst = ["tag:k8s", "tag:k8s-operator"]
        ip = ["tcp:80", "tcp:443"]
      }
    ]
  })
}

resource "tailscale_oauth_client" "this" {
  description = "homelab-tailscale-operator"
  scopes = ["devices:core", "auth_keys", "services"]
  tags = ["tag:k8s-operator"]

  depends_on = [tailscale_acl.this]
}

resource "helm_release" "tailscale_operator" {
  provider = helm.deploy

  name = "tailscale-operator"
  chart = "tailscale-operator"
  repository = "https://pkgs.tailscale.com/helmcharts"
  version = "1.98.4"
  namespace = "tailscale"
  create_namespace = true

  values = [
    yamlencode({
      oauth = {
        clientId = tailscale_oauth_client.this.id
        clientSecret = tailscale_oauth_client.this.key
      }
      ingressClass = {
        create = false
      }
      apiServerProxyConfig = {
        allowImpersonation = "true"
      }
      operatorConfig = {
        nodeSelector = {
          "niovial.io/node-purpose" = "system"
        }
        tolerations = [
          {
            key      = "niovial.io/node-purpose"
            operator = "Equal"
            value    = "system"
          }
        ]
      }
    })
  ]

  depends_on = [module.talos_k8s]
}

resource "helm_release" "kube-apiserver-proxy" {
  provider = helm.deploy

  name       = "kube-apiserver-proxy-manifest"
  repository = "https://bedag.github.io/helm-charts/"
  chart      = "raw"
  namespace  = "tailscale"

  values = [
    yamlencode({
      resources = [
        {
          apiVersion = "rbac.authorization.k8s.io/v1"
          kind = "ClusterRoleBinding"
          metadata = {
            name = "${var.project_name}-tailscale-admin"
          }
          subjects = [
            {
              kind = "Group"
              name = "tag:k8s-admin"
              apiGroup = "rbac.authorization.k8s.io"
            }
          ]
          roleRef = {
            kind = "ClusterRole"
            name = "cluster-admin"
            apiGroup = "rbac.authorization.k8s.io"
          }
        },
        {
          apiVersion = "tailscale.com/v1alpha1"
          kind       = "ProxyGroup"
          metadata = {
            name      = var.project_name
            namespace = "tailscale"
          }
          spec = {
            type     = "kube-apiserver"
            replicas = 2
            kubeAPIServer = {
              mode = "auth"
            }
          }
        }
      ]
    })
  ]

  depends_on = [helm_release.tailscale_operator]
}