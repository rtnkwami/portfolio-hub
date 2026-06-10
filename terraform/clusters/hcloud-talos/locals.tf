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
    xlarge = "cx53"
  }

  # To prevent cognitive overload, follow the comments below for the structure returned
  # by the nested loops
  node_pools = {
    # Generated structure (per group):
    # <group> = {
    #   <size> = [
    #     { name = "<group>-<size>-<zone_index+1>"... }
    #     { name = "<group>-<size>-<zone_index+1>"... }
    #     { name = "<group>-<size>-<zone_index+1>"... }
    #   ]
    # }

    # Example:
    # system = {
    #   small = [
    #     { name = "system-small-1"... }
    #     { name = "system-small-2"... }
    #     { name = "system-small-3"... }
    #   ]
    # }
    system = {
      for size in ["small", "medium"] :
      size => [
        for zone_index, zone in local.zones : {
          name = "system-${size}-${zone_index + 1}"
          type = local.node_sizes[size]
          location = zone
          min = 0
          max = 3
          labels = { "niovial.io/node-purpose" = "system" }
          taints = ["niovial.io/node-purpose=system:NoSchedule"]
        }
      ]
    }

    general = {
      for size in ["small", "medium", "large", "xlarge"] :
      size => [
        for zone_index, zone in local.zones : {
          name = "general-${size}-${zone_index + 1}"
          type = local.node_sizes[size]
          location = zone
          min = 0
          max = 10
          labels = { "niovial.io/node-purpose" = "general" }
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
  }
}