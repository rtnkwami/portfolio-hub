terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>3.0"
    }

    tailscale = {
      source = "tailscale/tailscale"
      version = "~>0.29.0"
    }
  }
}
