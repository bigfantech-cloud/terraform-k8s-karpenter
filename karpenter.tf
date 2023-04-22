resource "aws_iam_instance_profile" "karpenter" {
  name = "${module.this.id}-KarpenterNodeInstanceProfile"
  role = local.create_node_role ? aws_iam_role.this[0].name : local.external_role_name
}

resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true
  depends_on       = [module.iam_assumable_role_karpenter]

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "v0.21.1"

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "karpenter-controller"
  }

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "clusterEndpoint"
    value = var.cluster_endpoint
  }

  set {
    name  = "aws.defaultInstanceProfile"
    value = aws_iam_instance_profile.karpenter.name
  }

  set {
    name  = "settings.aws.interruptionQueueName"
    value = aws_sqs_queue.karpenter_spot_termination.name
  }

  set {
    name  = "logLevel"
    value = "debug"
  }
}

#----
# KUBERNETES Node Termination Queue
#----

resource "aws_sqs_queue" "karpenter_spot_termination" {
  count = var.enable_spot_termination ? 1 : 0

  name                      = "Karpenter-${var.cluster_name}-spot-termination"
  message_retention_seconds = 300

  tags = module.this.tags
}

data "aws_iam_policy_document" "karpenter_spot_termination" {
  count = var.enable_spot_termination ? 1 : 0

  statement {
    sid       = "SqsWrite"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.karpenter_spot_termination[0].arn]

    principals {
      type = "Service"
      identifiers = [
        "events.${local.aws_dns_suffix}",
        "sqs.${local.aws_dns_suffix}",
      ]
    }
  }
}

resource "aws_sqs_queue_policy" "karpenter_spot_termination" {
  count = var.enable_spot_termination ? 1 : 0

  queue_url = aws_sqs_queue.karpenter_spot_termination[0].url
  policy    = data.aws_iam_policy_document.karpenter_spot_termination[0].json
}

#---
# Node Termination Event Rules
#---

locals {
  events = {
    health_event = {
      name        = "HealthEvent"
      description = "Karpenter interrupt - AWS health event"
      event_pattern = {
        source      = ["aws.health"]
        detail-type = ["AWS Health Event"]
      }
    }
    spot_interupt = {
      name        = "SpotInterrupt"
      description = "Karpenter interrupt - EC2 spot instance interruption warning"
      event_pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Spot Instance Interruption Warning"]
      }
    }
    instance_rebalance = {
      name        = "InstanceRebalance"
      description = "Karpenter interrupt - EC2 instance rebalance recommendation"
      event_pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Instance Rebalance Recommendation"]
      }
    }
    instance_state_change = {
      name        = "InstanceStateChange"
      description = "Karpenter interrupt - EC2 instance state-change notification"
      event_pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Instance State-change Notification"]
      }
    }
  }
}

resource "aws_cloudwatch_event_rule" "karpenter_spot_termination" {
  for_each = { for k, v in local.events : k => v if var.enable_spot_termination }

  name_prefix   = "karpenter-${each.value.name}-"
  description   = each.value.description
  event_pattern = jsonencode(each.value.event_pattern)

  tags = merge(
    { "ClusterName" : var.cluster_name },
    module.this.tags,
  )
}

resource "aws_cloudwatch_event_target" "karpenter_spot_termination" {
  for_each = { for k, v in local.events : k => v if var.enable_spot_termination }

  rule      = aws_cloudwatch_event_rule.karpenter_spot_termination[each.key].name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.karpenter_spot_termination[0].arn
}
