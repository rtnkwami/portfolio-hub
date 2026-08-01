module "talos_k8s" {
  source = "./talos-k8s"

  hcloud_token = var.hcloud_token
  project_name = "homelab"

  talosconfig_path = "${path.module}/outputs/talosconfig"
  kubeconfig_path  = "${path.module}/outputs/kubeconfig"
  workloads        = local.workloads
}

resource "helm_release" "argocd" {
  provider = helm.deploy

  name             = "argocd"
  chart            = "argo-cd"
  repository       = "oci://ghcr.io/argoproj/argo-helm"
  version          = "10.2.2"
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