provider "aws" {}

provider "hcloud" {
  token = var.hcloud_token
}

provider "helm" {}

provider "helm" {
  alias = "deploy"
  kubernetes = {
    host = local.kubeconfig_data.server
    cluster_ca_certificate = local.kubeconfig_data.ca
    client_certificate = local.kubeconfig_data.cert
    client_key = local.kubeconfig_data.key
  }
}

provider "http" {}

provider "imager" {
  token = var.hcloud_token
}
