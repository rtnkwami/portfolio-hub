locals {
  network_cidr = "10.128.0.0/16"
  node_cidr = {
    # first /24
    app_cidr = cidrsubnet(local.network_cidr, 9, 0)
    db_cidr  = cidrsubnet(local.network_cidr, 9, 1)
    # second /24
    infra_cidr    = cidrsubnet(local.network_cidr, 9, 2)
    reserved_cidr = cidrsubnet(local.network_cidr, 9, 3)
    # /28 first network (16 IPs of reserved_cidr for control plane)
    control_plane_cidr = cidrsubnet(
      cidrsubnet(local.network_cidr, 9, 3), 3, 0
    )
  }
  k8s_cidr = {
    # third /24
    service_cidr = cidrsubnet(local.network_cidr, 8, 2)
    # /19 lots of ips for pods
    pod_cidr = cidrsubnet(local.network_cidr, 3, 1)
  }
}

resource "hcloud_network" "private_network" {
  name     = "${var.project_name}-network"
  ip_range = local.network_cidr
}

resource "hcloud_network_subnet" "load_balancer" {
  network_id   = hcloud_network.private_network.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = local.node_cidr.infra_cidr
}

resource "hcloud_network_subnet" "control_plane_subnet" {
  network_id   = hcloud_network.private_network.id
  type         = "cloud"
  network_zone = "eu-central"
  # 14 usable IPs for the control plane, because the control plane does not scale like workers do
  ip_range = local.node_cidr.control_plane_cidr
}

resource "hcloud_network_subnet" "app_subnet" {
  network_id   = hcloud_network.private_network.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = local.node_cidr.app_cidr
}

resource "hcloud_network_subnet" "database_subnet" {
  network_id   = hcloud_network.private_network.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = local.node_cidr.db_cidr
}
