locals {
  hcloud_secret_manifest = {
    name = "hcloud-secret"
    contents = yamlencode({
      apiVersion = "v1"
      kind       = "Secret"
      type       = "Opaque"
      metadata = {
        name      = "hcloud"
        namespace = "kube-system"
      }
      data = {
        network = base64encode(hcloud_network.private_network.id)
        token   = base64encode(var.hcloud_token)
      }
    })
  }
}

data "helm_template" "hcloud_ccm" {
  name         = "hcloud-cloud-controller-manager"
  namespace    = "kube-system"
  chart        = "hcloud-cloud-controller-manager"
  repository   = "https://charts.hetzner.cloud"
  version      = local.hcloud_ccm_version
  kube_version = local.k8s_version
  wait         = false

  values = [
    yamlencode({
      kind = "DaemonSet"
      nodeSelector = {
        "node-role.kubernetes.io/control-plane" = ""
      }
      # allow ccm to handle pod to pod and node to node networking on hcloud
      # used in conjunction with cilium native routing configuration
      networking = {
        enabled     = true
        clusterCIDR = local.k8s_cidr.pod_cidr
      }
      # all other env vars are default. You can find the full list of defaults here:
      # https://github.com/hetznercloud/hcloud-cloud-controller-manager/blob/main/docs/reference/load_balancer_envs.md
      # you can also find additional config at the below route:
      # https://github.com/hetznercloud/hcloud-cloud-controller-manager/blob/b7197db090e6cbc2e031d0982aeaba897646bbaf/internal/config/config.go#L206
      env = {
        HCLOUD_LOAD_BALANCERS_ENABLED                 = { value = "true" }
        HCLOUD_LOAD_BALANCERS_NETWORK_ZONE            = { value = "eu-central" }
        HCLOUD_LOAD_BALANCERS_USE_PRIVATE_IP          = { value = "true" }
        HCLOUD_LOAD_BALANCERS_ALGORITHM_TYPE          = { value = "least_connections" }
        HCLOUD_LOAD_BALANCERS_PRIVATE_SUBNET_IP_RANGE = { value = hcloud_network_subnet.load_balancer.ip_range }
        # it is possible that ipv6 config can conflict with the proxy protocol setting
        HCLOUD_LOAD_BALANCERS_DISABLE_IPV6            = { value = "true" }
        # do not allow traffic that should be external to be routable via the private network of the load balancer
        HCLOUD_LOAD_BALANCERS_DISABLE_PRIVATE_INGRESS = { value = "true" }
        # the proxy protocol allows cilium to keep track of the src ip of a packet despite it being
        # forwarded by a gateway (to prevent it's src from being replaced by the load balancer)
        HCLOUD_LOAD_BALANCERS_USES_PROXYPROTOCOL      = { value = "true" }
        KUBERNETES_SERVICE_HOST                       = { value = local.k8s_service_host }
        KUBERNETES_SERVICE_PORT                       = { value = tostring(local.k8s_service_port) }
      }
    })
  ]
}

locals {
  hcloud_ccm_manifest = {
    name     = "hcloud-ccm"
    contents = data.helm_template.hcloud_ccm.manifest
  }
}
