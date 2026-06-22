data "http" "current_ipv4" {
  url = "https://ipv4.icanhazip.com"

  retry {
    attempts     = 10
    min_delay_ms = 1000
    max_delay_ms = 1000
  }
}

locals {
  server_locations = toset(["nbg1", "fsn1", "hel1"])
  current_ip = "${chomp(data.http.current_ipv4.response_body)}/32"
  bootstrap_node_key = "fsn1"
  k8s_version = "v1.36"
  talos_version = "v1.13"
}