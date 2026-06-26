locals {
  # this is changed from "localhost" to "127.0.0.1" because
  # if it isn't cilium will try to do a dns lookup for localhost to
  # resolve the DNS name on both IPv4 and IPv6, causing an error when it
  # can't find the IPv6 address.
  # IPv6 isn't enabled by default on this cluster
  k8s_service_host = "127.0.0.1"
  # For future reference, this port number was orignall 7443 and shot me in the foot
  # next time reference this https://docs.siderolabs.com/kubernetes-guides/advanced-guides/kubeprism#:~:text=port
  k8s_service_port = 7445
}

data "helm_template" "cilium" {
  name         = "cilium"
  namespace    = "kube-system"
  repository   = "oci://quay.io/cilium/charts"
  chart        = "cilium"
  version      = var.cilium_version
  kube_version = var.k8s_version
  wait         = false

  values = [
    yamlencode({
      # each node is assigned a CIDR range for pods besides their own IP
      ipam = { mode = "kubernetes" }
      # configure cilium to use VPC routable pod IP CIDR
      # This works in conjuction with hcloud ccm to handle IPAM
      # hetnzer cloud networks are l3, so we cannot route on L2 (see https://docs.hetzner.com/networking/networks/technical-concepts/architecture/#:~:text=Cloud%20subnet%20at%20Layer%203%20%28IP%20%2F%20Network%20Layer%29%3A).
      # the native routing mode that has to be used is this (https://docs.cilium.io/en/stable/network/concepts/routing/#native-routing:~:text=The%20node%20itself%20does%20not)
      routingMode = "native"
      k8s = {
        requireIPv4PodCIDR = true
      }
      ipv4NativeRoutingCIDR = local.k8s_cidr.pod_cidr
      # enable eBPF masquerading instead of legacy iptables masquerading
      # eBPF is more efficient.
      bpf = {
        masquerade = true
      }
      encryption = {
        enabled        = true
        type           = "wireguard"
        nodeEncryption = true
      }
      kubeProxyReplacement = true
      securityContext = {
        capabilities = {
          ciliumAgent      = ["CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK", "SYS_ADMIN", "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID"]
          cleanCiliumState = ["NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE"]
        }
      }
      cgroup = {
        autoMount = { enabled = false }
        hostRoot  = "/sys/fs/cgroup"
      }
      # we use localhost here because talos has kube-prism installed by default
      # kube-prism provides a load balancer reachable on port 7445 for workers
      # to communicate with the control plane. Since cilium replaces kube-proxy, it
      # needs a way to be routed to the cluster endpoint. As such, even if we don't use the
      # load balancer endpoint (which is the cluster's actual control plane endpoint)
      # we can still access the cluster endpoint via kube-prism
      k8sServiceHost = local.k8s_service_host
      k8sServicePort = local.k8s_service_port
      gatewayAPI = {
        enabled = true
      }
      operator = {
        nodeSelector = {
          "niovial.io/node-purpose" = "system"
        }
        tolerations = [
          {
            key      = "niovial.io/node-purpose"
            operator = "Equal"
            value    = "system"
          },
          {
            key      = "node.kubernetes.io/not-ready"
            operator = "Exists"
          }
        ]
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
            key      = "niovial.io/node-purpose"
            operator = "Equal"
            value = "system"
          }]
        }
        ui = {
          enabled = true
          nodeSelector = {
            "niovial.io/node-purpose" = "system"
          }
          tolerations = [{
            key      = "niovial.io/node-purpose"
            operator = "Equal"
            value = "system"
          }]
        }
      }
      prometheus = {
        enabled = true
        serviceMonitor = {
          enabled        = true
          trustCRDsExist = true
        }
      }
    })
  ]
}

locals {
  cilium_manifest = {
    name     = "cilium"
    contents = data.helm_template.cilium.manifest
  }
}