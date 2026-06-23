data "helm_template" "cilium" {
  name       = "cilium"
  namespace  = "kube-system"
  repository = "oci://quay.io/cilium/charts"
  chart      = "cilium"
  version    = var.cilium_version
  kube_version = var.k8s_version
  wait       = false

  values = [
    yamlencode({
      ipam = { mode = "kubernetes" }
      kubeProxyReplacement = true
      securityContext = {
        capabilities = {
          ciliumAgent = ["CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK", "SYS_ADMIN", "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID"]
          cleanCiliumState = ["NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE"]
        }
      }
      cgroup = {
        autoMount = { enabled = false }
        hostRoot = "/sys/fs/cgroup"
      }
      # we use localhost here because talos has kube-prism installed by default
      # kube-prism provides a load balancer reachable on port 7445 for workers
      # to communicate with the control plane. Since cilium replaces kube-proxy, it
      # needs a way to be routed to the cluster endpoint. As such, even if we don't use the
      # load balancer endpoint (which is the cluster's actual control plane endpoint)
      # we can still access the cluster endpoint via kube-prism
      k8sServiceHost = "localhost"
      k8sServicePort = 7445
      gatewayAPI = { 
        enabled = true
      }
      operator = {
        nodeSelector = { 
          "niovial.io/node-purpose" = "system"
        }
        tolerations = [{
          key = "niovial.io/node-purpose"
          operator = "Exists"
        }]
        podDisruptionBudget = {
          enabled = true
        }
      }
      hubble = {
        enabled = true
        relay = {
          enabled = true
          nodeSelector = { 
            "niovial.io/node-purpose" = "system"
          }
          tolerations = [{
            key = "niovial.io/node-purpose"
            operator = "Exists"
          }]
        }
        ui = {
          enabled = true
            nodeSelector = { 
            "niovial.io/node-purpose" = "system"
          }
          tolerations = [{
            key = "niovial.io/node-purpose"
            operator = "Exists"
          }]
        }
      }
      prometheus = {
        enabled = true
        serviceMonitor = {
          enabled = true
          trustCRDsExist = true
        }
      }
    })
  ]
}

locals {
  cilium_manifest = {
    name = "cilium"
    contents = <<-EOF
      ${data.helm_template.cilium.manifest}
    EOF
  }
}