data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  account_id     = data.aws_caller_identity.current.account_id
  aws_partition  = data.aws_partition.current.aws_partition
  aws_dns_suffix = data.aws_partition.current.dns_suffix
}
