data "http" "current_ipv4" {
  url = "https://ipv4.icanhazip.com"

  retry {
    attempts     = 10
    min_delay_ms = 1000
    max_delay_ms = 1000
  }
}

locals {
  nodepools = {
    system = {
      sizes = {
        small  = "cx23"
        medium = "cx33"
      }
      min = 0
      max = 3
      labels = {
        "niovial.io/node-purpose" = "system"
      }
      taints = [
        {
          key    = "niovial.io/node-purpose"
          value  = "system"
          effect = "NoSchedule"
        }
      ]
    }
    general = {
      sizes = {
        small  = "cx23"
        medium = "cx33"
        large  = "cx43"
      }
      min = 0
      max = 20
      labels = {
        "niovial.io/node-purpose" = "general"
      }
      taints = []
    }
    database = {
      sizes = {
        medium = "cx33"
        large  = "cx43"
      }
      min = 0
      max = 10
      labels = {
        "niovial.io/node-purpose" = "database"
      }
      taints = [
        {
          key    = "niovial.io/node-purpose"
          value  = "database"
          effect = "NoSchedule"
        }
      ]
    }
  }
  tailscale_admin_role_binding = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind = "ClusterRoleBinding"
    metadata = {
      name = "${var.project_name}-tailscale-admin"
    }
    subjects = [
      {
        kind = "Group"
        name = "tag:k8s-admin"
        apiGroup = "rbac.authorization.k8s.io"
      }
    ]
    roleRef = {
      kind = "ClusterRole"
      name = "cluster-admin"
      apiGroup = "rbac.authorization.k8s.io"
    }
  }
  kube_apiserver_proxy_class = {
    apiVersion = "tailscale.com/v1alpha1"
    kind = "ProxyClass"
    metadata = {
      name = "${var.project_name}-proxy-class"
      namespace = "tailscale"
    }
    spec = {
      statefulSet = {
        pod = {
          nodeSelector = {
            "niovial.io/node-purpose" = "system"
          }
          tolerations = [
            {
              key = "niovial.io/node-purpose",
              operator = "Equal"
              value = "system"
            }
          ]
          topologySpreadConstraints = [
            {
              topologyKey       = "topology.kubernetes.io/zone"
              maxSkew           = 1
              whenUnsatisfiable = "DoNotSchedule"
              labelSelector = {
                matchLabels = {
                  "tailscale.com/parent-resource"      = var.project_name
                  "tailscale.com/parent-resource-type" = "proxygroup"
                }
              }
              matchLabelKeys = ["controller-revision-hash"]
            }
          ]
        }
      }
    }
  }
  kube_apiserver_proxy = {
    apiVersion = "tailscale.com/v1alpha1"
    kind       = "ProxyGroup"
    metadata = {
      name      = var.project_name
      namespace = "tailscale"
    }
    spec = {
      proxyClass = "${var.project_name}-proxy-class"
      type     = "kube-apiserver"
      replicas = 2
      kubeAPIServer = {
        mode = "auth"
      }
    }
  }
}