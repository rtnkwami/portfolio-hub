terraform {
  backend "s3" {
    bucket       = "niovial-opentofu-state"
    key          = "talos-hcloud-cluster"
    encrypt      = true
    region       = var.opentofu_state_bucket_region
    use_lockfile = true
  }
}
