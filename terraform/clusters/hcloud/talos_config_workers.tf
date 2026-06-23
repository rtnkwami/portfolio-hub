locals {
  talos_version = var.talos_version
  k8s_version = var.k8s_version
}

data "talos_machine_configuration" "worker" {
  cluster_name = var.project_name
  machine_type = "worker"
  cluster_endpoint = "https://${hcloud_load_balancer.control_plane_lb.ipv4}:6443"
  machine_secrets = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.k8s_version
  talos_version = var.talos_version
}

resource "talos_machine_configuration_apply" "worker_config" {
  for_each = hcloud_server.workers

  client_configuration = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
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

  depends_on = [ talos_machine_bootstrap.controlplane ]
}