terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.40.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
  }
}