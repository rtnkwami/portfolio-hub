resource "hcloud_load_balancer" "control_plane_lb" {
  name = "controlplane-lb"
  load_balancer_type = "lb11"
  network_zone = "eu-central"
}

resource "hcloud_load_balancer_network" "cp_lb_attachment" {
  load_balancer_id = hcloud_load_balancer.control_plane_lb.id
  network_id = hcloud_network.private_network.id
}

resource "hcloud_load_balancer_service" "kube_api_listener" {
  load_balancer_id = hcloud_load_balancer.control_plane_lb.id
  protocol = "tcp"
  listen_port = 6443
  destination_port = 6443

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
  load_balancer_id = hcloud_load_balancer.control_plane_lb.id
  label_selector = "niovial.io/node-purpose=control-plane"
}