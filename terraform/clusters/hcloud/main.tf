module "talos_k8s" {
  source = "./talos-k8s"

  hcloud_token = var.hcloud_token
  project_name = "homelab"

  talosconfig_path = "${path.module}/outputs/talosconfig"
  kubeconfig_path  = "${path.module}/outputs/kubeconfig"
  workloads        = local.workloads

  tailscale_client_id = var.tailscale_client_id
  tailscale_client_secret = var.tailscale_client_secret
}

resource "helm_release" "argocd" {
  provider = helm.deploy

  name             = "argocd"
  chart            = "argo-cd"
  repository       = "oci://ghcr.io/argoproj/argo-helm"
  version          = "9.7.0"
  namespace        = "argocd"
  create_namespace = true
  wait             = false

  values = [
    yamlencode({
      configs = {
        params = {
          "server.insecure" = "true"
        }
      }
      global = {
        tolerations = [
          {
            key      = "node.niovial.io/pool"
            operator = "Equal"
            value    = "system"
          }
        ]
        nodeSelector = {
          "node.niovial.io/pool" = "system"
        }
      }
    })
  ]
  depends_on = [module.talos_k8s]
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

resource "kubernetes_namespace_v1" "tailscale" {
  metadata {
    name = "tailscale"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
  depends_on = [module.talos_k8s]
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
  namespace = kubernetes_namespace_v1.tailscale.metadata[0].name

  values = [
    yamlencode({
      oauth = {
        clientId = tailscale_oauth_client.this.id
        clientSecret = tailscale_oauth_client.this.key
      }
      ingressClass = {
        create = false
      }
      operatorConfig = {
        nodeSelector = {
          "node.niovial.io/pool" = "system"
        }
        tolerations = [
          {
            key      = "node.niovial.io/pool"
            operator = "Equal"
            value    = "system"
          }
        ]
      }
    })
  ]

  depends_on = [module.talos_k8s]
}