locals {
  argocd_namespace_manifest = {
    apiVersion = "v1"
    kind = "Namespace"
    metadata = {
      name = "argocd"
    }
  }
}

data "helm_template" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  repository       = "oci://ghcr.io/argoproj/argo-helm"
  chart            = "argo-cd"
  version          = "9.7.0"
  kube_version = local.k8s_version
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
}

locals {
  argocd_manifest = {
    name = "argocd"
    contents = <<-EOF
      ${yamlencode(local.argocd_namespace_manifest)}
      ---
      ${data.helm_template.argocd.manifest}
    EOF
  }
}