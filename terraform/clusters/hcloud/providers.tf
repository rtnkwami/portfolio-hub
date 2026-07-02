provider "aws" {}

provider "helm" {}

provider "helm" {
  alias = "deploy"

  kubernetes = {
    host                   = module.talos_k8s.kubeconfig_data.server
    cluster_ca_certificate = module.talos_k8s.kubeconfig_data.ca
    client_certificate     = module.talos_k8s.kubeconfig_data.cert
    client_key             = module.talos_k8s.kubeconfig_data.key
  }
}

provider "http" {}

provider "kubernetes" {
  host                   = module.talos_k8s.kubeconfig_data.server
  cluster_ca_certificate = module.talos_k8s.kubeconfig_data.ca
  client_certificate     = module.talos_k8s.kubeconfig_data.cert
  client_key             = module.talos_k8s.kubeconfig_data.key
}

provider "tailscale" {
  oauth_client_id = var.tailscale_client_id
  oauth_client_secret = var.tailscale_client_secret
}