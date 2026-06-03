variable "hcloud_token" {
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