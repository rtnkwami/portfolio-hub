terraform {
  required_providers {
    # needed for s3 backend (see backend.tf)
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"
    }

    talos = {
      source  = "siderolabs/talos"
      version = "0.12.0-alpha.4"
    }

    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~>1.0"
    }

    imager = {
      source = "hcloud-talos/imager"
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
  }
}
