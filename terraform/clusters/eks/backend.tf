terraform {
  backend "s3" {
    bucket       = "niovial-opentofu-state"
    key          = "portfolio-eks-tfstate"
    encrypt      = true
    region       = var.deployment_region
    use_lockfile = true
  }
}