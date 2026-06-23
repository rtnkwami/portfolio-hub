resource "talos_machine_secrets" "this" {}

data "talos_client_configuration" "this" {
  cluster_name = var.project_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes = concat(
    [for node in hcloud_server.control_plane : node.ipv4_address],
    [for node in hcloud_server.workers : node.ipv4_address]
  )
  endpoints = [for node in hcloud_server.control_plane : node.ipv4_address]
}

resource "local_sensitive_file" "talosconfig" {
  content         = data.talos_client_configuration.this.talos_config
  filename        = "${path.module}/outputs/talosconfig"
  file_permission = "0600"
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node = hcloud_server.control_plane[local.bootstrap_node_key].ipv4_address
  depends_on = [talos_machine_bootstrap.controlplane]
}

resource "local_sensitive_file" "kubeconfig" {
  content         = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename        = "${path.module}/outputs/kubeconfig"
  file_permission = "0600"
}
