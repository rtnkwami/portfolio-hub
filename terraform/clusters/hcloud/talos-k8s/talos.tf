resource "talos_machine_secrets" "this" {}

data "talos_client_configuration" "this" {
  cluster_name         = var.project_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes = concat(
    [for node in hcloud_server.control_plane : node.ipv4_address],
    [for node in hcloud_server.workers : node.ipv4_address]
  )
  endpoints = [for node in hcloud_server.control_plane : node.ipv4_address]
}

resource "local_sensitive_file" "talosconfig" {
  content         = data.talos_client_configuration.this.talos_config
  filename        = var.talosconfig_path
  file_permission = "0600"
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = hcloud_server.control_plane[local.bootstrap_node_key].ipv4_address
  depends_on           = [talos_machine_bootstrap.controlplane]
}

resource "local_sensitive_file" "kubeconfig" {
  content         = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename        = var.kubeconfig_path
  file_permission = "0600"
}

resource "time_sleep" "wait_cluster_health_2m" {
  depends_on = [talos_machine_configuration_apply.worker_config]
  create_duration = "120s"
}

locals {
  kubeconfig_data = {
    name   = var.project_name
    server = local.cluster_endpoint
    ca     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
    cert   = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
    key    = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
  }
}
