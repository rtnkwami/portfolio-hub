locals {
  talos_version                    = "v1.13.4"
  k8s_version                      = "v1.36.1"
  talos_ccm_version                = "v1.12.0"
  prometheus_operator_crds_version = "v0.92.0"
  gateway_api_crds_version         = "v1.5.1"
  cilium_version                   = "1.19.4"
  hcloud_ccm_version               = "1.33.0"
  hcloud_csi_version               = "2.21.2"
  cluster_autoscaler_version       = "9.58.0"

  cluster_endpoint = "https://${hcloud_load_balancer.control_plane_lb.ipv4}:6443"
  zones            = ["nbg1", "fsn1", "hel1"]
}