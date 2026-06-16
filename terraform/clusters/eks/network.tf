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
    "kubernetes.io/role/internal-elb" = 1
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
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