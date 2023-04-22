variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "The EKS cluster endpoint"
  type        = string
}

variable "enable_spot_termination" {
  description = "Determines whether to enable native spot termination handling. Default = false"
  type        = bool
  default     = false
}

variable "karpenter_sa_additional_iam_policies_arn_list" {
  description = "List of IAM policies ARN to attach with Karpenter ServiceAccount IAM role"
  type        = list(string)
  default     = []
}

variable "cluster_ip_family" {
  description = "The IP family used to assign Kubernetes pod and service addresses. Valid values are `ipv4` (default) and `ipv6`"
  type        = string
  default     = "ipv4"
}

variable "create_node_role" {
  description = "Create an IAM role or to use an existing IAM role for nodes that Karpenter provisions"
  type        = bool
  default     = true
}

variable "node_role_additional_iam_policies_arn_list" {
  description = "List of IAM policies ARN to attach with node role"
  type        = list(string)
  default     = []
}

variable "custom_node_role_name" {
  description = "Name of custom created IAM role, to attach with nodes that Karpenter provisions"
  type        = string
  default     = null
}
