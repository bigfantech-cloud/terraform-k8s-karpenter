output "karpenter_node_instance_profile_name" {
  description = "Node Instance profile name"
  value       = aws_iam_instance_profile.karpenter.name
}

output "karpenter_node_iam_role_arn" {
  description = "Node IAM role ARN"
  value       = local.create_node_role ? aws_iam_role.this[0].arn : null
}

output "karpenter_node_spot_termination_sqs_queue_name" {
  description = "Node spot termination SQS queue name"
  value       = var.enable_spot_termination ? aws_sqs_queue.karpenter_spot_termination.name : null
}

output "karpenter_node_spot_termination_sqs_queue_id" {
  description = "Node spot termination SQS queue ID"
  value       = var.enable_spot_termination ? aws_sqs_queue.karpenter_spot_termination.id : null
}

output "karpenter_node_spot_termination_sqs_queue_arn" {
  description = "Node spot termination SQS queue ARN"
  value       = var.enable_spot_termination ? aws_sqs_queue.karpenter_spot_termination.arn : null
}
