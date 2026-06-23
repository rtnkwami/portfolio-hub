locals {
  bootstrap_node_key = "fsn1"
}

data "talos_machine_configuration" "controlplane" {
  cluster_name = var.project_name
  machine_type = "controlplane"
  cluster_endpoint = "https://${hcloud_load_balancer.control_plane_lb.ipv4}:6443"
  machine_secrets = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.k8s_version
  talos_version = var.talos_version
}

resource "talos_machine_configuration_apply" "controlplane_config" {
  for_each = hcloud_server.control_plane

  client_configuration = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node = each.value.ipv4_address
  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda"
        }
      }
    })
  ]
}

resource "talos_machine_bootstrap" "controlplane" {
  depends_on = [
    talos_machine_configuration_apply.controlplane_config
  ]
  node                 = hcloud_server.control_plane[local.bootstrap_node_key].ipv4_address
  client_configuration = talos_machine_secrets.this.client_configuration
}