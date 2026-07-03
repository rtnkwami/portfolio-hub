module "talos_k8s" {
  source = "./talos-k8s"

  hcloud_token = var.hcloud_token
  project_name = "homelab"

  talosconfig_path = "${path.module}/outputs/talosconfig"
  kubeconfig_path  = "${path.module}/outputs/kubeconfig"
  nodepools        = local.nodepools
}

# Infisical is used as the external secret store for the cluster
resource "kubernetes_namespace_v1" "external_secrets" {
  metadata {
    name = "external-secrets"
  }

  depends_on = [module.talos_k8s]
}

resource "kubernetes_secret_v1" "infisical_creds" {
  metadata {
    name      = "infisical-credentials"
    namespace = kubernetes_namespace_v1.external_secrets.metadata[0].name
  }

  data_wo = {
    clientId     = var.infisical_client_id
    clientSecret = var.infisical_client_secret
  }
  data_wo_revision = 1
  immutable        = true
}

resource "kubernetes_namespace_v1" "tailscale" {
  metadata {
    name = "tailscale"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }

  depends_on = [module.talos_k8s]
}

resource "tailscale_acl" "this" {
  overwrite_existing_content = true
  acl = jsonencode({
    tagOwners = {
      "tag:k8s-operator" = ["autogroup:admin"]
      "tag:k8s" = ["tag:k8s-operator"]
    }
    autoApprovers = {
      services = {
        "tag:k8s" = ["tag:k8s"]
      }
    }
    acls = [
      # Allow everything to talk to everything on the tailnet. This should
      # be used on personal and test tailnets only.
      {
        action = "accept"
        src = ["*"]
        dst = ["*:*"]
      }
    ]
    grants = [
      # Allow everything on the tailnet to talk to the API Server Proxy.
      {
        src = ["*"]
        dst = ["tag:k8s-operator"]
        ip = ["tcp:443"]
      }
    ]
    nodeAttrs = [
      # Let the Kubernetes operator use Tailscale Funnel
      { target = ["tag:k8s"], attr = ["funnel"] } # tag that the Tailscale operator uses to tag proxies; defaults to 'tag:k8s'
    ]
  })
}

resource "tailscale_oauth_client" "this" {
  description = "homelab-tailscale-operator"
  scopes = ["devices:core", "auth_keys", "services"]
  tags = ["tag:k8s-operator"]

  depends_on = [tailscale_acl.this]
}

resource "helm_release" "tailscale_operator" {
  provider = helm.deploy

  name = "tailscale-operator"
  repository = "https://pkgs.tailscale.com/helmcharts"
  chart = "tailscale-operator"
  version = "1.98.4"
  namespace = kubernetes_namespace_v1.tailscale.metadata[0].name
  wait = false

  values = [
    yamlencode({
      oauth = {
        clientId = tailscale_oauth_client.this.id
        clientSecret = tailscale_oauth_client.this.key
      }
      ingressClass = {
        create = false
      }
      operatorConfig = {
        nodeSelector = {
          "niovial.io/node-purpose" = "system"
        }
        tolerations = [
          {
            key      = "niovial.io/node-purpose"
            operator = "Equal"
            value    = "system"
          }
        ]
      }
    })
  ]

  depends_on = [module.talos_k8s]
}