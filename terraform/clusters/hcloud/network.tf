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

resource "hcloud_server_network" "cp_network_attachment" {
  for_each = hcloud_server.control_plane

  server_id = each.value.id
  network_id = hcloud_network.private_network.id
}

resource "hcloud_load_balancer" "controlplane_lb" {
  name = "controlplane-lb"
  load_balancer_type = "lb11"
  network_zone = "eu-central"
}

# attach lb to network
resource "hcloud_load_balancer_network" "cp_lb_attachment" {
  load_balancer_id = hcloud_load_balancer.controlplane_lb.id
  network_id = hcloud_network.private_network.id
}

resource "hcloud_load_balancer_service" "cp__lb_listener" {
  load_balancer_id = hcloud_load_balancer.controlplane_lb.id
  protocol = "tcp"
  # kube-apiserver listens on 6443
  listen_port = 6443
  destination_port = 6443

  # verify that kube-apiserver can be reached
  health_check {
    protocol = "tcp"
    port = 6443
    retries = 3
    interval = 10
    timeout = 5
  }
}

resource "hcloud_load_balancer_target" "cp_lb_target" {
  type = "label_selector"
  load_balancer_id = hcloud_load_balancer.controlplane_lb.id
  label_selector = "niovial.io/node-purpose=control-plane"
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

