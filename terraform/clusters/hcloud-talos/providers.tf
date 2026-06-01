provider "aws" {}

provider "hcloud" {
  token = var.hcloud_token
}

provider "helm" {
  kubernetes = {
    host = module.kubernetes.kubeconfig_data.server
    cluster_ca_certificate = module.kubernetes.kubeconfig_data.ca
    client_certificate = module.kubernetes.kubeconfig_data.cert
    client_key = module.kubernetes.kubeconfig_data.key
  }
}