locals {
  talos_version = var.talos_version
  k8s_version   = var.k8s_version
  worker_config = {
    machine = {
      install = {
        disk = "/dev/sda"
      }
      nodeLabels = {
        "niovial.io/node-purpose" = "system"
      }
      kubelet = {
        # because the default service cidr was changed, kubelet's baked in service cidr
        # needs to be changed to reflect that. The same changes are also made on the control plane
        # see (talos_config_control_plane.tf)
        # also note that kube-dns (the service for coredns) is always the tenth IP of your
        # cluster's entire service IP cidr range. 
        clusterDNS = [cidrhost(local.k8s_cidr.service_cidr, 10)]
        extraConfig = {
          registerWithTaints = [
            {
              key    = "niovial.io/node-purpose"
              value  = "system"
              effect = "NoSchedule"
            }
          ]
        }
      }
    }
  }
}

data "talos_machine_configuration" "worker" {
  cluster_name       = var.project_name
  machine_type       = "worker"
  cluster_endpoint   = "https://${hcloud_load_balancer.control_plane_lb.ipv4}:6443"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.k8s_version
  talos_version      = var.talos_version
}

resource "talos_machine_configuration_apply" "worker_config" {
  for_each = hcloud_server.workers

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = each.value.ipv4_address
  config_patches              = [yamlencode(local.worker_config)]

  depends_on = [talos_machine_bootstrap.controlplane]
}