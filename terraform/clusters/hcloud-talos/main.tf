module "kubernetes" {
  source = "hcloud-k8s/kubernetes/hcloud"
  version = "~>4.0"

  hcloud_token = var.hcloud_token
  cluster_delete_protection = false

  cluster_name = "homelab"
  cluster_talosconfig_path = "./outputs/talosconfig"
  cluster_kubeconfig_path = "./outputs/kubeconfig"

  cilium_gateway_api_enabled = true
  cilium_hubble_enabled = true
  cilium_hubble_relay_enabled = true
  cilium_service_monitor_enabled = true
  cilium_helm_values = {
    hubble = {
      relay = { tolerations = [local.system_taint] }
    }
  }

  cluster_allow_scheduling_on_control_planes = false
  # enable this option only if you add additional control plane nodes
  # kube_api_load_balancer_enabled = true
  
  control_plane_nodepools = [
    { name = "control", type = "cx23", location = "hel1", count = 1 },
    # { name = "control", type = "cx23", location = "fsn1", count = 1 },
    # { name = "control", type = "cx23", location = "nbg1", count = 1 }
  ]

  worker_nodepools = [
    {
      name = "system-1"
      type = "cx23"
      location = "hel1"
      count = 1
      labels = { "niovial.io/node-purpose" = "system" }
      taints = ["niovial.io/node-purpose=system:NoSchedule"]
    },
    {
      name     = "system-2"
      type     = "cx23"
      location = "fsn1"
      count    = 1
      labels = { "niovial.io/node-purpose" = "system" }
      taints = ["niovial.io/node-purpose=system:NoSchedule" ]
    }
  ]

  cluster_autoscaler_discovery_enabled = true
  cluster_autoscaler_cleanup_enabled = true
  cluster_autoscaler_helm_values = {
    extraArgs = {
      expander = "least-waste"
    }
  }

  cluster_autoscaler_nodepools = concat(
    flatten(values(local.node_pools.general)),
    flatten(values(local.node_pools.database)),
    flatten(values(local.node_pools.observability)),
  )
}

resource "helm_release" "argocd" {
  name = "argocd"
  namespace = "argocd"
  create_namespace = true
  repository = "oci://ghcr.io/argoproj/argo-helm"
  chart = "argo-cd"
  wait = false
  values = [
    yamlencode({
      global = {
        tolerations = [local.system_taint]
        nodeSelector = {
          "niovial.io/node-purpose" = "system"
        }
      }
    })
  ]
  
  depends_on = [ module.kubernetes ]
}