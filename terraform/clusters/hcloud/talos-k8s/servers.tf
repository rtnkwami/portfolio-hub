locals {
  talos_image      = "https://factory.talos.dev/image/376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba/v1.13.4/hcloud-amd64.raw.xz"
  server_locations = toset(local.zones)
}

resource "imager_image" "talos_x86" {
  image_url    = local.talos_image
  architecture = "x86"
  server_type  = "cx23"

  timeouts {
    create = "10m"
  }

  labels = {
    version = local.talos_version
  }
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
}

resource "random_uuid" "ssh_key_id" {}

# the only reason this key exists is to prevent Hetzner from sending an email
# every time a server is created, either via this module or via the cluster autoscaler
resource "hcloud_ssh_key" "this" {
  name       = "${var.project_name}-default-key-${random_uuid.ssh_key_id.id}"
  public_key = tls_private_key.ssh_key.public_key_openssh

  labels = {
    "niovial.io/cluster" = var.project_name
  }
}

resource "hcloud_server" "control_plane" {
  for_each = local.server_locations

  name        = "controlplane-node-${each.key}"
  server_type = "cx33"
  location    = each.value
  image       = imager_image.talos_x86.id
  ssh_keys    = [hcloud_ssh_key.this.id]

  public_net {
    ipv4_enabled = true
  }

  labels = {
    "niovial.io/node-purpose" = "control-plane"
  }
}

resource "hcloud_server_network" "control_plane_attachment" {
  for_each = hcloud_server.control_plane

  server_id = hcloud_server.control_plane[each.key].id
  subnet_id = hcloud_network_subnet.control_plane_subnet.id
}

resource "hcloud_server" "workers" {
  for_each = local.server_locations

  name        = "system-node-${each.key}"
  location    = each.value
  server_type = "cx23"
  image       = imager_image.talos_x86.id
  ssh_keys    = [hcloud_ssh_key.this.id]

  public_net {
    ipv4_enabled = true
  }

  labels = {
    "niovial.io/node-purpose" = "system"
  }
}

resource "hcloud_server_network" "worker_attachment" {
  for_each = hcloud_server.workers

  server_id = hcloud_server.workers[each.key].id
  subnet_id = hcloud_network_subnet.app_subnet.id
}