data "aws_availability_zones" "available_azs" {
  state = "available"
}

data "aws_iam_policy" "cni_policy" {
  name = "AmazonEKS_CNI_Policy"
}

data "aws_iam_policy" "worker_node_policy" {
  name = "AmazonEKSWorkerNodePolicy"
}

data "aws_iam_policy" "ecr_pull_only_policy" {
  name = "AmazonEC2ContainerRegistryPullOnly"
}

data "aws_iam_policy" "ssm_access_policy" {
  name = "AmazonSSMManagedInstanceCore"
}

locals {
  azs = slice(data.aws_availability_zones.available_azs.names, 0, 3)
  versions = {
    kubernetes = "1.36"
    modules = {
      vpc          = "6.6.1"
      eks          = "21.23.0"
      pod_identity = "2.8.1"
    }
    helm_releases = {
      fluxcd         = "0.52.0"
      ebs_csi_driver = "2.62.0"
      cilium         = "1.19.4"
    }
  }
  global_tags = {
    "niovial.io/project"    = var.project_name
    "niovial.io/managed-by" = "OpenTofu"
  }
}

