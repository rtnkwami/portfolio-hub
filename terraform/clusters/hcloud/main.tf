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
