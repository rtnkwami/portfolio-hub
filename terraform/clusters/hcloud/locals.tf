data "http" "current_ipv4" {
  url = "https://ipv4.icanhazip.com"

  retry {
    attempts     = 10
    min_delay_ms = 1000
    max_delay_ms = 1000
  }
}

locals {
  nodepools = {
    system = {
      sizes = {
        small = "cx23"
        medium = "cx33" 
      }
      min = 0
      max = 3
      labels = {
        "niovial.io/node-purpose" = "system"
      }
      taints = [
        { 
          key = "niovial.io/node-purpose"
          value = "system"
          effect = "NoSchedule"
        }
      ]
    }
    general = {
      sizes = {
        small  = "cx23"
        medium = "cx33"
        large  = "cx43"
        xlarge = "cx53"
      }
      min    = 0
      max    = 20
      labels = {
        "niovial.io/node-purpose" = "general"
      }
      taints = []
    }
    database = {
      sizes = {
        medium = "cx33"
        large  = "cx43"
      }
      min    = 0
      max    = 10
      labels = {
        "niovial.io/node-purpose" = "database"
      }
      taints = [
        { 
          key = "niovial.io/node-purpose"
          value = "database"
          effect = "NoSchedule"
        }
      ]
    }
  }
}