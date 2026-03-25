# Hub VPC — isolated network for hub control plane

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.cluster_name}-vpc"
  cidr = local.vpc_cidr

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = [cidrsubnet(local.vpc_cidr, 4, 0), cidrsubnet(local.vpc_cidr, 4, 1), cidrsubnet(local.vpc_cidr, 4, 2)]
  public_subnets  = [cidrsubnet(local.vpc_cidr, 4, 3), cidrsubnet(local.vpc_cidr, 4, 4), cidrsubnet(local.vpc_cidr, 4, 5)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}
