terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.11.0"
    }

    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~>1.0"
    }

    imager = {
      source  = "hcloud-talos/imager"
      version = "~>1.0"
    }

    # needed to install cilium cni, argocd, etc. (see helm.tf)
    helm = {
      source  = "hashicorp/helm"
      version = "~>3.0"
    }

    http = {
      source  = "hashicorp/http"
      version = "~>3.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~>4.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~>2.0"
    }
  }
}
