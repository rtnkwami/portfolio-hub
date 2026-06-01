module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = local.versions.modules.vpc

  name            = "${var.project_name}-vpc"
  cidr            = var.vpc_cidr
  azs             = local.azs
  private_subnets = [for index, value in local.azs : cidrsubnet(var.vpc_cidr, 4, index)]
  public_subnets  = [for index, value in local.azs : cidrsubnet(var.vpc_cidr, 8, index + 112)]

  private_subnet_tags = {
    "karpenter.sh/discovery" = "${var.project_name}-eks-cluster"
  }

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  tags = {
    Project      = var.project_name
    ResourceType = "Networking"
    ManagedBy    = "OpenTofu"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = local.versions.modules.eks

  name               = "${var.project_name}-eks-cluster"
  kubernetes_version = "1.35"

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
    Name         = "${var.project_name}-eks-cluster"
    Project      = var.project_name
    ResourceType = "Compute"
    ManagedBy    = "OpenTofu"
  }

  tags = {
    Project = var.project_name
    ResourceType = "Compute"
    ManagedBy = "OpenTofu"
  }
}

module "aws_ebs_csi_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name = "aws-ebs-csi"
  attach_aws_ebs_csi_policy = true

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "ebs-csi-controller-sa"
    }
  }
}

resource "helm_release" "cilium" {
  name = "cilium"
  namespace = "kube-system"
  repository = "oci://quay.io/cilium/charts"
  chart = "cilium"
  version = local.versions.helm_releases.cilium
  wait = false

  values = [
    yamlencode({
      operator = {
        tolerations = [{
          key = "CriticalAddonsOnly"
          operator = "Equal"
          value = "true"
          effect = "NoSchedule"
        }]
      }
      hubble = {
        relay = {
          enabled = true
          rollOutPods = true
          tolerations = [{
            key      = "niovial.io/node-purpose"
            operator = "Equal"
            value    = "monitoring"
            effect   = "NoSchedule"
          }]
        }
      }
      gatewayAPI = { enabled = true }
      eni = { enabled = true }
      ipam = { mode = "eni" }
      egressMasqueradeInterfaces = "eth0"
      routingMode = "native"
      kubeProxyReplacement = "true"
      k8sServiceHost = replace(module.eks.cluster_endpoint, "https://", "")
      k8sServicePort = "443"
    })
  ]
}

module "eks_managed_node_group" {
  source = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = local.versions.modules.eks

  name = "system-nodes"
  cluster_name = module.eks.cluster_name
  cluster_service_cidr = module.eks.cluster_service_cidr
  cluster_endpoint = module.eks.cluster_endpoint
  cluster_auth_base64 = module.eks.cluster_certificate_authority_data

  subnet_ids = module.vpc.private_subnets

  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  vpc_security_group_ids = [module.eks.node_security_group_id]
  
  iam_role_additional_policies = {
    cilium_eni = data.aws_iam_policy.cni_policy.arn
    worker_node = data.aws_iam_policy.worker_node_policy.arn
    image_pull_only = data.aws_iam_policy.ecr_pull_only_policy.arn
    ssm_access_policy = data.aws_iam_policy.ssm_access_policy.arn
  }

  min_size = 1
  desired_size = 2
  max_size = 3

  instance_types = ["t4g.medium"]
  ami_type = "AL2023_ARM_64_STANDARD"
  capacity_type = "ON_DEMAND"

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

  depends_on = [ helm_release.cilium ]
}

resource "aws_eks_addon" "coredns" {
  cluster_name = module.eks.cluster_name
  addon_name = "coredns"
  resolve_conflicts_on_update = "PRESERVE"
  
  configuration_values = jsonencode({
    nodeSelector = {
      "niovial.io/node-purpose" = "system"
    }
    tolerations = [{
      key      = "CriticalAddonsOnly"
      operator = "Equal"
      value    = "true"
      effect   = "NoSchedule"
    }]
  })

  depends_on = [ module.eks_managed_node_group ]
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
            operator = "Equal"
            value    = "true"
            effect   = "NoSchedule"
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

module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = local.versions.modules.eks
  cluster_name = module.eks.cluster_name
  node_iam_role_name = "KarpenterNodeRole-${module.eks.cluster_name}"
  node_iam_role_use_name_prefix = false
  enable_spot_termination = true
  queue_name = "KarpenterInterruptionQueue-${module.eks.cluster_name}"

  depends_on = [ aws_eks_addon.coredns ]
}