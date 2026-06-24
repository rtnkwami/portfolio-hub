provider "aws" {}

provider "hcloud" {
  token = var.hcloud_token
}

provider "http" {}

provider "imager" {
  token = var.hcloud_token
}
