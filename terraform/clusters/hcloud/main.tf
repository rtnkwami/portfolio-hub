data "talos_cluster_health" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for node in hcloud_server.control_plane : node.ipv4_address]
  # for etcd checks, and other control plane checks talos cluster health expects the private IPs
  # of the control plane nodes. Internal cluster healt checks should not be going over the internet
  # hence, the private IPs of the control plane nodes are used here.
  control_plane_nodes  = [for node in hcloud_server_network.control_plane_attachment : node.ip]
  worker_nodes         = [for node in hcloud_server_network.worker_attachment : node.ip]
  
  depends_on           = [talos_machine_configuration_apply.worker_config]
}

resource "helm_release" "argocd" {
  provider = helm.deploy
  
  name = "argocd"
  namespace = "argocd"
  create_namespace = true
  repository = "oci://ghcr.io/argoproj/argo-helm"
  chart = "argo-cd"
  version = var.argocd_version
  wait = false
  
  values = [
    yamlencode({
      global = {
        tolerations = [
          {
            key      = "niovial.io/node-purpose"
            operator = "Equal"
            value    = "system"
          }
        ]
        nodeSelector = {
          "niovial.io/node-purpose" = "system"
        }
      }
    })
  ]

  depends_on = [ data.talos_cluster_health.this ]
}