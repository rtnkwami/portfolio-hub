module "talos_k8s" {
  source = "./talos-k8s"

  hcloud_token = var.hcloud_token
  project_name = "homelab"

  talosconfig_path = "${path.module}/outputs/talosconfig"
  kubeconfig_path = "${path.module}/outputs/kubeconfig"
  nodepools = local.nodepools
}

resource "helm_release" "argocd" {
  provider = helm.deploy

  name = "argocd"
  namespace = "argocd"
  create_namespace = true
  repository = "oci://ghcr.io/argoproj/argo-helm"
  chart = "argo-cd"
  version = "9.7.0"
  wait = false
  
  values = [
    yamlencode({
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