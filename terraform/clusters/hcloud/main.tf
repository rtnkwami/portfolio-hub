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
  repository       = "https://argoproj.github.io/argo-helm"
  version          = "10.2.2"
  namespace        = "argocd"
  create_namespace = true
  wait             = false

    values = [
      yamlencode({
        configs = {
          # although argocd manages itself, at the very least, we need
          # app healthchecks to remain in effect before making it manage itself.
          cm = {
            "resource.customizations.health.argoproj.io_Application" = <<-EOF
              hs = {}
              hs.status = "Progressing"
              hs.message = ""
              if obj.status ~= nil then
                if obj.status.health ~= nil then
                  hs.status = obj.status.health.status
                  if obj.status.health.message ~= nil then
                    hs.message = obj.status.health.message
                  end
                end
              end
              return hs
            EOF
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
  
  # we do this because argocd manages itself
  lifecycle {
    ignore_changes = [
      values,
      version,
      namespace,
      name,
      chart,
    ]
  }
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