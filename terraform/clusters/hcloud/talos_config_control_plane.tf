locals {
  bootstrap_node_key = "fsn1"
  cloud_manifests = [
    # use the cloud controller manager daemonset to ensure redundancy
    "https://raw.githubusercontent.com/siderolabs/talos-cloud-controller-manager/${var.talos_ccm_version}/docs/deploy/cloud-controller-manager-daemonset.yml",
    # these manifests are installed on control plane bootstrap because they are required by the following components:
    # Cilium -> both Gateway API and exposing a Prometheus Service Monitor
    # ArgoCD -> exposing a Prometheus Service Monitor
    # this is only needed on initial cluster bootstrap, because the CRDs get replaced later with VMServiceScrape by the
    # victoria-metrics-k8s-stack
    "https://github.com/prometheus-operator/prometheus-operator/releases/download/${var.prometheus_operator_crds_version}/stripped-down-crds.yaml",
    "https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_crds_version}/experimental-install.yaml"
    ]
  
  fundamental_manifests = concat(
    [local.hcloud_secret_manifest],
    [local.cilium_manifest],
    [local.hcloud_ccm_manifest]
  )

  control_plane_config = {
    machine = {
      install = {
        disk = "/dev/sda"
      }
      kubelet = {
        extraArgs = {
          cloud-provider = "external"
          rotate-server-certificates = true
        }
        # see talos_config_workers.tf for more information
        clusterDNS = [cidrhost(local.k8s_cidr.service_cidr, 10)]
      }
      features = {
        kubernetesTalosAPIAccess = {
          enabled = true
          allowedRoles = ["os:reader"]
          allowedKubernetesNamespaces = ["kube-system"]
        }
      }
    }
    cluster = {
      inlineManifests = local.fundamental_manifests
      externalCloudProvider = {
        enabled = true
        manifests = local.cloud_manifests
      }
      controllerManager = {
        # configure controller manager to use external ccm
        # instead of in-tree provider
        extraArgs = {
          "cloud-provider" = "external"
          "node-cidr-mask-size-ipv4" = "26" # each node should use 64 IPs
        }
      }
      network = {
        cni = {
          name = "none"
        }
        podSubnets = [local.k8s_cidr.pod_cidr]
        serviceSubnets = [local.k8s_cidr.service_cidr]
      }
      proxy = {
        disabled = true
      }
    }
  }
}

data "talos_machine_configuration" "controlplane" {
  cluster_name = var.project_name
  machine_type = "controlplane"
  cluster_endpoint = "https://${hcloud_load_balancer.control_plane_lb.ipv4}:6443"
  machine_secrets = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.k8s_version
  talos_version = var.talos_version
}

resource "talos_machine_configuration_apply" "controlplane_config" {
  for_each = hcloud_server.control_plane

  client_configuration = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node = each.value.ipv4_address
  config_patches = [yamlencode(local.control_plane_config)]
}

resource "talos_machine_bootstrap" "controlplane" {
  depends_on = [
    talos_machine_configuration_apply.controlplane_config
  ]
  node                 = hcloud_server.control_plane[local.bootstrap_node_key].ipv4_address
  client_configuration = talos_machine_secrets.this.client_configuration
}