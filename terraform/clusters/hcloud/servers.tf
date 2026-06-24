locals {
  talos_image      = var.talos_machine_image
  server_locations = toset(["nbg1", "fsn1", "hel1"])
}

resource "imager_image" "talos_x86" {
  image_url    = local.talos_image
  architecture = "x86"
  server_type  = "cx23"

  timeouts {
    create = "10m"
  }

  labels = {
    version = var.talos_version
  }
}

resource "hcloud_server" "control_plane" {
  for_each = local.server_locations

  name        = "controlplane-node-${each.key}"
  server_type = "cx23"
  location    = each.value
  image       = imager_image.talos_x86.id

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