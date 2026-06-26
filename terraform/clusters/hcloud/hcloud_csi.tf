

data "helm_template" "hcloud_csi" {
  name = "hcloud-csi"
  namespace = "kube-system"
  repository = "https://charts.hetzner.cloud"
  chart = "hcloud-csi"
  version = var.hcloud_csi_version
  kube_version = var.k8s_version
  wait = false

  values = [
    yamlencode({
      controller = {
        replicaCount = 2
        podDisruptionBudget = {
          create = true
          minAvailable = null
          maxUnavailable = "1"
        }
        topologySpreadConstraints = [
          {
            topologyKey       = "topology.kubernetes.io/zone"
            maxSkew           = 1
            whenUnsatisfiable = "DoNotSchedule"
            labelSelector = {
              matchLabels = {
                "app.kubernetes.io/name"      = "hcloud-csi"
                "app.kubernetes.io/instance"  = "hcloud-csi"
                "app.kubernetes.io/component" = "controller"
              }
            }
            matchLabelKeys = ["pod-template-hash"]
          }
        ],
        nodeSelector = {
          "niovial.io/node-purpose" = "system"
        }
        tolerations = [
          {
            key      = "niovial.io/node-purpose"
            operator = "Equal"
            value    = "system"
          }
        ],
      }
      # storage classes are not provisioned in this chart
      # besides the default, as encryption of volumes is handled
      # via an external secret. Hetzner has no support for encryption of
      # volumes. Rather the CSI can handle volume encryption using client side keys
    })
  ]
}

locals {
  hcloud_csi_manifest = {
    name     = "hcloud-csi"
    contents = data.helm_template.hcloud_csi.manifest
  }
}