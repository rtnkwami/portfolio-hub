data "http" "current_ipv4" {
  url = "https://ipv4.icanhazip.com"

  retry {
    attempts     = 10
    min_delay_ms = 1000
    max_delay_ms = 1000
  }
}

locals {
  workloads = {
    system = {
      min = 0
      max = 3
      labels = {
        "node.niovial.io/pool" = "system"
      }
      taints = [
        {
          key    = "node.niovial.io/pool"
          value  = "system"
          effect = "NoSchedule"
        }
      ]
    }
    general = {
      min = 0
      max = 20
      labels = {
        "node.niovial.io/pool" = "general"
      }
      taints = []
    }
    database = {
      min = 0
      max = 10
      labels = {
        "node.niovial.io/pool" = "database"
      }
      taints = [
        {
          key    = "node.niovial.io/pool"
          value  = "database"
          effect = "NoSchedule"
        }
      ]
    }
  }
}