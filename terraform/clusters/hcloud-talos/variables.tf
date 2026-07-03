variable "hcloud_token" {
  sensitive = true
}

variable "project_name" {
  type = string
  default = "homelab"
}

variable "cloudflare_dns_token" {
  sensitive = true
}

variable "infisical_client" {
  sensitive = true
}

variable "infisical_secret" {
  sensitive = true
}

variable "deployment_region" {
  default = "us-east-1"
}