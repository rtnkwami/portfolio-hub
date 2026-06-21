variable "opentofu_state_bucket_region" {
  default = "us-east-1"
}

variable "hcloud_token" {
  sensitive = true
}

variable "project_name" {
  type = string
  default = "homelab"
}
