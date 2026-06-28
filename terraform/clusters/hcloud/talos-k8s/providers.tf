provider "hcloud" {
  token = var.hcloud_token
}

provider "imager" {
  token = var.hcloud_token
}
