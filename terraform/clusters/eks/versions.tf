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

  backend "s3" {
    bucket       = "niovial-opentofu-state"
    key          = "portfolio-eks-tfstate"
    encrypt      = true
    region       = var.deployment_region
    use_lockfile = true
  }
}