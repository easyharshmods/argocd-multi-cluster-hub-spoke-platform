# ──────────────────────────────────────────────────────────────────────────────
# AWS Load Balancer Controller IRSA role
# ──────────────────────────────────────────────────────────────────────────────
module "aws_lb_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.cluster_name}-aws-lb-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.common_tags
}

# Allow ALB controller to integrate with Cognito for listener authentication
resource "aws_iam_role_policy" "aws_lb_controller_cognito" {
  name = "cognito-auth"
  role = "${local.cluster_name}-aws-lb-controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "cognito-idp:DescribeUserPoolClient"
        Resource = "*"
      }
    ]
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# External Secrets IRSA role - reads secrets from Secrets Manager
# ──────────────────────────────────────────────────────────────────────────────
module "external_secrets_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.cluster_name}-external-secrets"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-secrets-system:external-secrets"]
    }
  }

  role_policy_arns = {
    policy = aws_iam_policy.external_secrets.arn
  }

  tags = local.common_tags
}

resource "aws_iam_policy" "external_secrets" {
  name        = "${local.cluster_name}-external-secrets"
  description = "Policy for External Secrets Operator to access Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = [local.shared.rds_secret_arn]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = [local.shared.secrets_kms_key_arn]
      }
    ]
  })

  tags = local.common_tags
}

# ──────────────────────────────────────────────────────────────────────────────
# External DNS IRSA role - manages Route53 records for ALB Ingresses
# ──────────────────────────────────────────────────────────────────────────────
module "external_dns_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.cluster_name}-external-dns"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }

  role_policy_arns = {
    policy = aws_iam_policy.external_dns.arn
  }

  tags = local.common_tags
}

resource "aws_iam_policy" "external_dns" {
  name        = "${local.cluster_name}-external-dns"
  description = "Policy for External DNS to manage Route53 records"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/${local.shared.route53_zone_id}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource"
        ]
        Resource = ["*"]
      }
    ]
  })

  tags = local.common_tags
}

# ──────────────────────────────────────────────────────────────────────────────
# ADOT Collector IRSA role - sends traces to AWS X-Ray
# ──────────────────────────────────────────────────────────────────────────────
module "adot_collector_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.cluster_name}-adot-collector"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["observability:adot-collector"]
    }
  }

  # Use AWSXRayDaemonWriteAccess managed policy for minimal X-Ray permissions
  role_policy_arns = {
    xray = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
  }

  tags = local.common_tags
}

# ──────────────────────────────────────────────────────────────────────────────
# Cluster Autoscaler IRSA role - scales EKS managed node groups
# ──────────────────────────────────────────────────────────────────────────────
module "cluster_autoscaler_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.cluster_name}-cluster-autoscaler"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }

  role_policy_arns = {
    autoscaler = aws_iam_policy.cluster_autoscaler.arn
  }

  tags = local.common_tags
}

resource "aws_iam_policy" "cluster_autoscaler" {
  name        = "${local.cluster_name}-cluster-autoscaler"
  description = "Cluster Autoscaler policy for scaling EKS managed node groups"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeLaunchTemplateVersions"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

# ──────────────────────────────────────────────────────────────────────────────
# Fluent Bit IRSA role - ships container logs to CloudWatch Logs
# ──────────────────────────────────────────────────────────────────────────────
module "fluent_bit_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.cluster_name}-fluent-bit"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["logging:fluent-bit"]
    }
  }

  role_policy_arns = {
    cloudwatch = local.shared.fluent_bit_cloudwatch_policy_arn
  }

  tags = local.common_tags
}

# ──────────────────────────────────────────────────────────────────────────────
# ECR KMS decrypt policy for EKS node group (to pull encrypted images)
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_iam_policy" "ecr_kms_decrypt" {
  name        = "${local.cluster_name}-ecr-kms-decrypt"
  description = "Allow EKS node group to decrypt ECR images encrypted with KMS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = local.shared.ecr_kms_key_arn
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "node_group_ecr_kms" {
  role       = try(split("/", module.eks.eks_managed_node_groups["hub"].iam_role_arn)[1], "hub-nodes-eks-node-group-*")
  policy_arn = aws_iam_policy.ecr_kms_decrypt.arn

  depends_on = [module.eks]
}
