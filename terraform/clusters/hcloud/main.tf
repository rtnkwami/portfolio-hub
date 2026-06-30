module "talos_k8s" {
  source = "./talos-k8s"

  hcloud_token = var.hcloud_token
  project_name = "homelab"

  talosconfig_path = "${path.module}/outputs/talosconfig"
  kubeconfig_path  = "${path.module}/outputs/kubeconfig"
  nodepools        = local.nodepools
}

resource "helm_release" "argocd" {
  provider = helm.deploy

  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "oci://ghcr.io/argoproj/argo-helm"
  chart            = "argo-cd"
  version          = "9.7.0"
  wait             = false

  values = [
    yamlencode({
      configs = {
        cm = {
          "timeout.reconciliation" = "60s"
          "timeout.reconciliation.jitter" = "30s"
        }
      }
      global = {
        tolerations = [
          {
            key      = "niovial.io/node-purpose"
            operator = "Equal"
            value    = "system"
          }
        ]
        nodeSelector = {
          "niovial.io/node-purpose" = "system"
        }
      }
    })
  ]

  depends_on = [module.talos_k8s]
}

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