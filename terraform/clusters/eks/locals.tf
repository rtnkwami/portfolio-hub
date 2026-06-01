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
    modules = {
      vpc = "6.6.1"
      eks = "21.18.0"
      pod_identity = "2.8.0"
    }
    helm_releases = {
      argocd = "9.5.14"
      ebs_csi_driver = "2.60.0"
      cilium = "1.19.4"
    } 
  }
}

