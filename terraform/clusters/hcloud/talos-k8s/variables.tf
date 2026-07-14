variable "hcloud_token" {
  sensitive = true
}

variable "project_name" {
  type = string
}

variable "talosconfig_path" {
  type = string
}

variable "kubeconfig_path" {
  type = string
}

variable "workloads" {
  type = map(object({
    min    = number
    max    = number
    labels = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
}

variable "tailscale_client_id" {
  sensitive = true
}

variable "tailscale_client_secret" {
  sensitive = true
}
