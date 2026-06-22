resource "imager_image" "talos_x86" {
  image_url = "https://factory.talos.dev/image/376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba/v1.13.4/hcloud-amd64.raw.xz"
  architecture = "x86"
  server_type = "cx23"

  timeouts {
    create = "10m"
  }

  labels = {
    version = "1.13.4"
  }
}

resource "hcloud_server" "control_plane" {
  for_each = local.server_locations
  
  name = "controlplane-node-${each.key}"
  server_type = "cx23"
  location = each.value
  image = imager_image.talos_x86.id

  public_net {
    ipv4_enabled = true
  }

  labels = {
    "niovial.io/node-purpose" = "control-plane"
  }
}

# generate machine secrets for turning control plane nodes into talos control plane
resource "talos_machine_secrets" "this" {}

data "talos_machine_configuration" "this" {
  cluster_name = var.project_name
  machine_type = "controlplane"
  cluster_endpoint = "https://${hcloud_load_balancer_network.cp_lb_attachment.ip}:6443"
  machine_secrets = talos_machine_secrets.this.machine_secrets
  kubernetes_version = local.k8s_version
  talos_version = local.talos_version
}

data "talos_client_configuration" "this" {
  cluster_name = var.project_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes = [for node in hcloud_server.control_plane : node.ipv4_address]
}

resource "local_sensitive_file" "talosconfig" {
  content         = data.talos_client_configuration.this.talos_config
  filename        = "${path.module}/outputs/talosconfig"
  file_permission = "0600"
}

resource "talos_machine_configuration_apply" "this" {
  for_each = hcloud_server.control_plane

  client_configuration = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this.machine_configuration
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

resource "talos_machine_bootstrap" "this" {
  depends_on = [
    talos_machine_configuration_apply.this
  ]
  node                 = hcloud_server.control_plane[local.bootstrap_node_key].ipv4_address
  client_configuration = talos_machine_secrets.this.client_configuration
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node = hcloud_server.control_plane[local.bootstrap_node_key].ipv4_address
  depends_on = [talos_machine_bootstrap.this]
}