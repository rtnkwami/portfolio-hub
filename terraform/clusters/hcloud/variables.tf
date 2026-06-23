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

variable "tailscale_client_id" {
  sensitive = true
}

variable "tailscale_client_secret" {
  sensitive = true
}
