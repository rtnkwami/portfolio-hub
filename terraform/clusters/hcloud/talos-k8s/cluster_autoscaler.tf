locals {
  expander_priorities = {
    "100" = [".*-cx23-.*", ".*-cax11-.*"]
    "90" = [".*-cx33-.*", ".*-cax21-.*"]
    "80" = [".*-cx43-.*", ".*-cpx22-.*", ".*-cax31-.*"]
    "70" = [".*-cpx32-.*", ".*-ccx13-.*"]
    "60" = [".*-cpx42-.*", ".*-ccx23-.*"]
  }
  # create a nodepool per intent, instance type, and zone
  # this is meant to satisfy topology spread constraints such as
  # topology.kubernetes.io/zone and hostname, among others
  # The reason for this design is that cluster autoscaler is unlike
  # karpenter and thus cannot do just-in-time provisioning of nodes based
  # on the exact requests of pods. So we have to bake that config in ourselves
  ca_nodepools = flatten([
    for nodepool_name, nodepool in var.nodepools : [
      for size_name, instance_type in nodepool.sizes : [
        for zone_index, zone in local.zones : {
          name          = "${nodepool_name}-${size_name}-${zone_index + 1}"
          instance_type = instance_type
          location      = zone
          min           = nodepool.min
          max           = nodepool.max
          labels        = nodepool.labels
          taints        = nodepool.taints
        }
      ]
    ]
  ])
  # this secret is created at bootstrap for cluster autoscaler to be initialized with
  # the nodepools that it needs to create. Nodepools are fixed and are not easily changed
  # at runtime.
  cluster_autoscaler_config = {
    apiVersion = "v1"
    kind       = "Secret"
    type       = "Opaque"
    metadata = {
      name      = "cluster-autoscaler-config-secret"
      namespace = "kube-system"
    }
    data = {
      cluster-config = base64encode(
        jsonencode({
          imagesForArch = {
            amd64 = imager_image.talos_x86.id
          },
          nodeConfigs = {
            for pool in local.ca_nodepools : pool.name => {
              cloudInit = data.talos_machine_configuration.cluster_autoscaler_config[pool.name].machine_configuration
              labels    = pool.labels
              taints    = pool.taints
            }
          }
        })
      )
    }
  }
}

data "helm_template" "cluster_autoscaler" {
  name         = "cluster-autoscaler"
  namespace    = "kube-system"
  repository   = "https://kubernetes.github.io/autoscaler"
  chart        = "cluster-autoscaler"
  version      = local.cluster_autoscaler_version
  kube_version = local.k8s_version

  values = [
    yamlencode({
      cloudProvider = "hetzner"
      replicaCount  = 2
      podDisruptionBudget = {
        minAvailable   = null
        maxUnavailable = 1
      }
      topologySpreadConstraints = [
        {
          topologyKey       = "topology.kubernetes.io/zone"
          maxSkew           = 1
          whenUnsatisfiable = "DoNotSchedule"
          labelSelector = {
            matchLabels = {
              "app.kubernetes.io/instance" = "cluster-autoscaler"
            }
          }
          matchLabelKeys = ["pod-template-hash"]
        }
      ]
      nodeSelector = {
        "niovial.io/node-purpose" = "system"
      }
      tolerations = [
        {
          key      = "niovial.io/node-purpose"
          operator = "Equal"
          value    = "system"
        }
      ]
      serviceMonitor = {
        enabled   = true
        namespace = "observability"
      }
      expanderPriorities = local.expander_priorities
      autoscalingGroups = [
        for nodepool in local.ca_nodepools : {
          name         = nodepool.name
          instanceType = nodepool.instance_type
          region       = nodepool.location
          minSize      = nodepool.min
          maxSize      = nodepool.max
        }
      ]
      extraArgs = {
        expander = "priority"
      }
      extraEnv = {
        # secret is created as "cluster-config". k8s mounts this due to extraVolumeSecrets below
        # as the path specified in extraVolumeSecrets + the secret key.
        HCLOUD_CLUSTER_CONFIG_FILE = "/config/cluster-config"
        HCLOUD_SSH_KEY             = tostring(hcloud_ssh_key.this.id)
        HCLOUD_PUBLIC_IPV4         = "true"
        HCLOUD_NETWORK             = tostring(hcloud_network.private_network.id)
      }
      # needed to call hcloud API to provision nodes
      # also for secrets passed as environment variables
      extraEnvSecrets = {
        HCLOUD_TOKEN = {
          name = "hcloud"
          key  = "token"
        }
      }
      # secrets to be mounted as a file (like .env)
      # and read by the controller
      extraVolumeSecrets = {
        cluster-autoscaler-config-secret = {
          name      = "cluster-autoscaler-config-secret"
          mountPath = "/config"
        }
      }
    })
  ]
}

locals {
  cluster_autoscaler_manifest = {
    name     = "cluster-autoscaler"
    contents = <<-EOF
      ${data.helm_template.cluster_autoscaler.manifest}
      ---
      ${yamlencode(local.cluster_autoscaler_config)}
    EOF
  }
}