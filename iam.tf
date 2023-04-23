locals {
  create_node_role = var.create_node_role
  cni_policy       = var.cluster_ip_family == "ipv6" ? "arn:${local.aws_partition}:iam::aws:policy/AmazonEKS_CNI_IPv6_Policy" : "arn:${local.aws_partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
}

#---
# K8S SERVICEACCOUNT
#--

module "iam_assumable_role_serviceaccount_karpenter" {
  source  = "bigfantech-cloud/iam-assumable-k8s-oidc-role-with-k8s-serviceaccount/aws"
  version = "1.0.0"

  namespace               = "karpenter"
  service_account_name    = "karpenter-controller"
  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
  oidc_provider_arn       = module.eks.oidc_provider_arn
  iam_role_name           = var.karpenter_serviceaccount_iam_role_name
  policy_jsons_list       = [data.aws_iam_policy_document.karpenter_controller_policy.json]
  policy_arns_list        = var.karpenter_sa_additional_iam_policies_arn_list
}

data "aws_iam_policy_document" "karpenter_controller_policy" {
  statement {
    actions = [
      "ec2:CreateLaunchTemplate",
      "ec2:CreateFleet",
      "ec2:CreateTags",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeSpotPriceHistory",
      "pricing:GetProducts",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "ec2:TerminateInstances",
      "ec2:DeleteLaunchTemplate",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/karpenter.sh/discovery"
      values   = [var.cluster_name]
    }
  }

  statement {
    actions = ["ec2:RunInstances"]
    resources = [
      "arn:${local.aws_partition}:ec2:*:${local.account_id}:launch-template/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/karpenter.sh/discovery"
      values   = [var.cluster_name]
    }
  }

  statement {
    actions = ["ec2:RunInstances"]
    resources = [
      "arn:${local.aws_partition}:ec2:*::image/*",
      "arn:${local.aws_partition}:ec2:*:${local.account_id}:instance/*",
      "arn:${local.aws_partition}:ec2:*:${local.account_id}:spot-instances-request/*",
      "arn:${local.aws_partition}:ec2:*:${local.account_id}:security-group/*",
      "arn:${local.aws_partition}:ec2:*:${local.account_id}:volume/*",
      "arn:${local.aws_partition}:ec2:*:${local.account_id}:network-interface/*",
      "arn:${local.aws_partition}:ec2:*:${local.account_id}:subnet/*",
    ]
  }

  statement {
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:*:*:parameter/aws/service/*"]
  }

  statement {
    actions   = ["eks:DescribeCluster"]
    resources = ["arn:${local.aws_partition}:eks:*:${local.account_id}:cluster/${var.cluster_name}"]
  }

  statement {
    actions   = ["iam:PassRole"]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = var.enable_spot_termination ? ["true"] : []

    content {
      actions = [
        "sqs:DeleteMessage",
        "sqs:GetQueueUrl",
        "sqs:GetQueueAttributes",
        "sqs:ReceiveMessage",
      ]
      resources = [aws_sqs_queue.karpenter_spot_termination[0].arn]
    }
  }
}

#------
# NODE IAM ROLE
#------

data "aws_iam_policy_document" "assume_role" {
  count = local.create_node_role ? 1 : 0

  statement {
    sid     = "EKSNodeAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.${local.aws_dns_suffix}"]
    }
  }
}

resource "aws_iam_role" "this" {
  count = local.create_node_role ? 1 : 0

  name        = "Karpenter-NodeRole"
  description = "Role for nodes that Karpenter provisions"

  assume_role_policy    = data.aws_iam_policy_document.assume_role[0].json
  force_detach_policies = true

  tags = module.this.tags
}

# Policies attached ref https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group
resource "aws_iam_role_policy_attachment" "this" {
  for_each = { for k, v in toset(compact([
    "arn:${local.aws_partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:${local.aws_partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    local.cni_policy,
  ])) : k => v if local.create_node_role }

  policy_arn = each.value
  role       = aws_iam_role.this[0].name
}

resource "aws_iam_role_policy_attachment" "additional" {
  for_each = { for k, v in var.node_role_additional_iam_policies_arn_list : k => v if local.create_node_role }

  policy_arn = each.value
  role       = aws_iam_role.this[0].name
}

