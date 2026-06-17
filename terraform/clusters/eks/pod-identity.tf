module "karpenter" {
  source                        = "terraform-aws-modules/eks/aws//modules/karpenter"
  version                       = local.versions.modules.eks
  cluster_name                  = module.eks.cluster_name
  node_iam_role_name            = "karpenter-node-role-${module.eks.cluster_name}"
  node_iam_role_use_name_prefix = false
  enable_spot_termination       = true
  queue_name                    = "karpenter-interruption-queue-${module.eks.cluster_name}"
  enable_inline_policy = true

  tags = merge(local.global_tags)
}

module "aws_ebs_csi_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name                      = "aws-ebs-csi-driver"
  attach_aws_ebs_csi_policy = true

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "ebs-csi-controller-sa"
    }
  }
  tags = merge(local.global_tags)
}