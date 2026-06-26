variable "opentofu_state_bucket_region" {
  default = "us-east-1"
}

variable "hcloud_token" {
  sensitive = true
}

variable "project_name" {
  type = string
}

variable "talos_machine_image" {
  type = string
}

variable "talos_version" {
  type = string
}

variable "k8s_version" {
  type = string
}

variable "talos_ccm_version" {
  type = string
}

variable "prometheus_operator_crds_version" {
  type = string
}

variable "gateway_api_crds_version" {
  type = string
}

variable "cilium_version" {
  type = string
}

variable "hcloud_ccm_version" {
  type = string
}

variable "hcloud_csi_version" {
  type = string
}

variable "cluster_autoscaler_version" {
  type = string
}

variable "argocd_version" {
  type = string
}

variable "tailscale_client_id" {
  sensitive = true
}

variable "tailscale_client_secret" {
  sensitive = true
}
