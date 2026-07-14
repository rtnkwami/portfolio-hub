locals {
  cluster_autoscaler_talos_config = {
    for nodepool in local.ca_nodepools : nodepool.name => [
      {
        machine = {
          install = {
            disk = "/dev/sda"
          }
          files = [
            {
              path = "/etc/cri/conf.d/20-customization.part"
              op = "create"
              content = <<-EOF
                [plugins."io.containerd.cri.v1.images"]
                discard_unpacked_layers = false
              EOF
            }
          ]
          nodeLabels = nodepool.labels
          kubelet = {
            # see talos_config_workers.tf for why this is here
            clusterDNS = [cidrhost(local.k8s_cidr.service_cidr, 10)]
            extraConfig = {
              registerWithTaints = nodepool.taints
            }
            extraArgs = {
              # setting this flag on both control plane and worker nodes
              # ensures that the ccm works properly for both classes of nodes
              cloud-provider             = "external"
              rotate-server-certificates = true
            }
          }
        }
      }
    ]
  }
}

data "talos_machine_configuration" "cluster_autoscaler_config" {
  for_each = { for nodepool in local.ca_nodepools : nodepool.name => nodepool }

  cluster_name       = var.project_name
  machine_type       = "worker"
  cluster_endpoint   = local.cluster_endpoint
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = local.k8s_version
  talos_version      = local.talos_version
  # apparently config_patches can be used here and I never knew
  config_patches = [for config in local.cluster_autoscaler_talos_config[each.key] : yamlencode(config)]
}