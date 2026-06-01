locals {
  system_taint = {
    key      = "niovial.io/node-purpose"
    operator = "Equal"
    value    = "system"
    effect   = "NoSchedule"
  }

  zones = ["hel1", "fsn1", "nbg1"]

  general_nodepools = [
    for index, zone in local.zones : {
      name = "general-${index + 1}"
      type = "cx23"
      location = zone
      min = 0
      max = 3
      labels = { "niovial.io/node-purpose" = "general" }
      taints = ["niovial.io/node-purpose=general:NoSchedule"]
    }
  ]

  database_nodepools = [
    for index, zone in local.zones : {
      name = "database-${index + 1}"
      type = "cx33"
      location = zone
      min = 0
      max = 3
      labels = { "niovial.io/node-purpose" = "database" }
      taints = ["niovial.io/node-purpose=database:NoSchedule"]
    }
  ]

  observability_nodepools = [
    for index, zone in local.zones : {
      name = "observability-${index + 1}"
      type = "cx33"
      location = zone
      min = 0
      max = 3
      labels = { "niovial.io/node-purpose" = "observability" }
      taints = ["niovial.io/node-purpose=observability:NoSchedule"]
    }
  ]
}