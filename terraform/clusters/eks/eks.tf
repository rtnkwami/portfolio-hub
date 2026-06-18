module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = local.versions.modules.eks

  name               = "${var.project_name}-eks-cluster"
  kubernetes_version = local.versions.kubernetes

  endpoint_private_access                  = true
  endpoint_public_access                   = true
  authentication_mode                      = "API" # forces auth via access entries
  enable_cluster_creator_admin_permissions = true

  # disable EKS Auto Mode
  compute_config = {
    enabled = false
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  addons = {
    eks-pod-identity-agent = {
      before_compute = true
    }
  }

  node_security_group_tags = {
    "karpenter.sh/discovery" = "${var.project_name}-eks-cluster"
  }

  cluster_tags = {
      Name = "${var.project_name}-eks-cluster"
  }

  tags = merge(local.global_tags)
}

resource "helm_release" "cilium" {
  name       = "cilium"
  namespace  = "kube-system"
  repository = "oci://quay.io/cilium/charts"
  chart      = "cilium"
  version    = local.versions.helm_releases.cilium
  wait       = false

  values = [
    yamlencode({
      operator = {
        tolerations = [{
          key      = "CriticalAddonsOnly"
          operator = "Exists"
        }]
      }
      hubble = {
        relay = {
          enabled     = true
          rollOutPods = true
        }
      }
      gatewayAPI                 = { enabled = true }
      eni                        = { enabled = true }
      ipam                       = { mode = "eni" }
      egressMasqueradeInterfaces = "eth0"
      routingMode                = "native"
      kubeProxyReplacement       = "true"
      k8sServiceHost             = replace(module.eks.cluster_endpoint, "https://", "")
      k8sServicePort             = "443"
    })
  ]
}

module "eks_managed_node_group" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = local.versions.modules.eks

  name                 = "system-nodes"
  cluster_name         = module.eks.cluster_name
  cluster_service_cidr = module.eks.cluster_service_cidr
  cluster_endpoint     = module.eks.cluster_endpoint
  cluster_auth_base64  = module.eks.cluster_certificate_authority_data
  kubernetes_version = local.versions.kubernetes

  subnet_ids = module.vpc.private_subnets

  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks.node_security_group_id]

  iam_role_additional_policies = {
    cilium_eni        = data.aws_iam_policy.cni_policy.arn
    worker_node       = data.aws_iam_policy.worker_node_policy.arn
    image_pull_only   = data.aws_iam_policy.ecr_pull_only_policy.arn
    ssm_access_policy = data.aws_iam_policy.ssm_access_policy.arn
  }

  min_size     = 1
  desired_size = 2
  max_size     = 3

  instance_types = ["t4g.medium"]
  ami_type       = "AL2023_ARM_64_STANDARD"
  capacity_type  = "ON_DEMAND"

  taints = {
    critical_addons = {
      key    = "CriticalAddonsOnly"
      value  = "true"
      effect = "NO_SCHEDULE"
    },
  }
  labels = {
    "karpenter.sh/controller" = "true"
    "niovial.io/node-purpose" = "system"
  }
  update_config = {
    max_unavailable = 1
  }

  depends_on = [helm_release.cilium]
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "coredns"
  resolve_conflicts_on_update = "PRESERVE"

  configuration_values = jsonencode({
    nodeSelector = {
      "niovial.io/node-purpose" = "system"
    }
    tolerations = [{
      key      = "CriticalAddonsOnly"
      operator = "Exists"
    }]
  })

  depends_on = [module.eks_managed_node_group]
}

resource "helm_release" "ebs_csi_driver" {
  name = "ebs-csi-driver"
  namespace = "kube-system"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart = "aws-ebs-csi-driver"
  version = local.versions.helm_releases.ebs_csi_driver
  wait = false
  values = [
    yamlencode({
      controller = {
        nodeSelector = {
          "niovial.io/node-purpose" = "system"
        }
      }
      storageClasses = [
        {
          name = "standard"
          annotations = {
            "storageclass.kubernetes.io/is-default-class" = "true"
          }
          volumeBindingMode = "WaitForFirstConsumer"
          reclaimPolicy    = "Delete"
          parameters = {
            type      = "gp3"
            encrypted = "true"
          }
        }
      ]
    })
  ]
  depends_on = [aws_eks_addon.coredns]
}

resource "helm_release" "argocd" {
  name = "argocd"
  namespace = "argocd"
  create_namespace = true
  repository = "oci://ghcr.io/argoproj/argo-helm"
  chart = "argo-cd"
  version = local.versions.helm_releases.argocd
  values = [
    yamlencode({
      global = {
        tolerations = [
          {
            key      = "CriticalAddonsOnly"
            operator = "Exists"
          }
        ]
        node_selector = {
          "niovial.io/node-purpose" = "system"
        }
      }
    })
  ]
  depends_on = [ aws_eks_addon.coredns ]
}