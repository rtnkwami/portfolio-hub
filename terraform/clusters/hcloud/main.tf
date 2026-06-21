resource "hcloud_network" "private_network" {
  name = "${var.project_name}-network"
  ip_range = "10.128.0.0/16"
}

resource "hcloud_network_subnet" "controlplane_subnet" {
  network_id = hcloud_network.private_network.id
  type = "cloud"
  network_zone = "eu-central"
  # 14 usable IPs for the control plane, because the control plane does not scale like workers do
  ip_range = cidrsubnet(hcloud_network.private_network.ip_range, 12, 0)
}

resource "hcloud_network_subnet" "app_subnet" {
  network_id = hcloud_network.private_network.id
  type = "cloud"
  network_zone = "eu-central"
  ip_range = cidrsubnet(hcloud_network.private_network.ip_range, 4, 1)
}

resource "hcloud_network_subnet" "database_subnet" {
  network_id = hcloud_network.private_network.id
  type = "cloud"
  network_zone = "eu-central"
  ip_range = cidrsubnet(hcloud_network.private_network.ip_range, 4, 2)
}

resource "hcloud_network_subnet" "reserved_subnet" {
  network_id = hcloud_network.private_network.id
  type = "cloud"
  network_zone = "eu-central"
  ip_range = cidrsubnet(hcloud_network.private_network.ip_range, 4, 3)
}

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

# resource "hcloud_firewall" "firewall" {
#   name = "${var.project_name}-firewall"

#   rule {
#     direction = "in"
#     protocol = "tcp"
#     source_ips = [local.current_ip]
#     port = "5000"
#   }

#   rule {
#     direction = "in"
#     protocol = "tcp"
#     source_ips = [local.current_ip]
#     port = "5000"
#   }
# }
