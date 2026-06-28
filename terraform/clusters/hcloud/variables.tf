variable "opentofu_state_bucket_region" {
  default = "us-east-1"
}

variable "hcloud_token" {
  sensitive = true
}

variable "tailscale_client_id" {
  sensitive = true
}

variable "tailscale_client_secret" {
  sensitive = true
}
