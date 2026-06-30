variable "opentofu_state_bucket_region" {
  default = "us-east-1"
}

variable "hcloud_token" {
  sensitive = true
}

variable "infisical_client_id" {
  sensitive = true
}

variable "infisical_client_secret" {
  sensitive = true
}

variable "tailscale_client_id" {
  sensitive = true
}

variable "tailscale_client_secret" {
  sensitive = true
}
