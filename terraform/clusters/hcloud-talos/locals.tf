locals {
  system_taint = {
    key      = "niovial.io/node-purpose"
    operator = "Equal"
    value    = "system"
    effect   = "NoSchedule"
  }

  zones = ["hel1", "fsn1", "nbg1"]

  node_sizes = {
    small = "cx23"
    medium = "cx33"
    large = "cx43"
  }

  node_pools = {
    general = {
      for size in ["small", "medium", "large"] :
      size => [
        for zone_index, zone in local.zones : {
          name = "general-${size}-${zone_index + 1}"
          type = local.node_sizes[size]
          location = zone
          min = 0
          max = 3
          labels = { "niovial.io/node-purpose" = "general" }
          taints = ["niovial.io/node-purpose=general:NoSchedule"]
        }
      ]
    }

    database = {
      for size in ["medium", "large"] :
      size => [
        for zone_index, zone in local.zones : {
          name = "database-${size}-${zone_index + 1}"
          type = local.node_sizes[size]
          location = zone
          min = 0
          max = 3
          labels = { "niovial.io/node-purpose" = "database" }
          taints = ["niovial.io/node-purpose=database:NoSchedule"]
        }
      ]
    }

    observability = {
      for size_index, size in ["small", "medium",] :
      size => [
        for zone_index, zone in local.zones : {
          name = "observability-${size}-${zone_index + 1}"
          type = local.node_sizes[size]
          location = zone
          min = 0
          max = 3
          labels = { "niovial.io/node-purpose" = "observability" }
          taints = ["niovial.io/node-purpose=observability:NoSchedule"]
        }
      ]
    }
  }
}