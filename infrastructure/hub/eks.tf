# Hub EKS cluster — runs ArgoCD, Prometheus, Grafana (no application workloads)

# EBS CSI Driver IAM Role (required before EKS addon)
module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.cluster_name}-ebs-csi-driver"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.common_tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = "1.34"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  # Hub cluster is smaller — only runs ArgoCD and monitoring
  eks_managed_node_groups = {
    hub = {
      name           = "hub-nodes"
      instance_types = ["t3.small"]
      capacity_type  = "SPOT"

      min_size     = 2
      max_size     = 4
      desired_size = 2

      labels = {
        role = "hub"
      }
    }
  }

  # Enable IRSA
  enable_irsa = true

  enable_cluster_creator_admin_permissions = true

  # Cluster addons
  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
    }
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = aws_kms_key.eks.arn
  }

  tags = local.common_tags
}

resource "aws_kms_key" "eks" {
  description             = "KMS key for Hub EKS cluster encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    local.common_tags,
    { Name = "${local.cluster_name}-eks-encryption" }
  )
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${local.cluster_name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}
