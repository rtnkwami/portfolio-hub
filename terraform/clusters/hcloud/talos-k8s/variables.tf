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

variable "nodepools" {
  type = map(object({
    sizes = map(string)
    min = number
    max = number
    labels = map(string)
    taints = list(object({
      key = string
      value = string
      effect = string
    }))
  }))
}
