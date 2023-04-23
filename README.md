# BigFantech-Cloud

We automate your infrastructure.
You will have full control of your infrastructure, including Infrastructure as Code (IaC).

To hire, email: `bigfantech@yahoo.com`

# Purpose of this code

> Terraform module

- Install Karpenter in EKS Cluster
- Create AWS Instance profile for nodes that Karpenter provisions
- Create AWS IAM role for nodes that Karpenter provisions

## Variables

### Required Variables

| Name             | Description                 |
| ---------------- | --------------------------- |
| cluster_name     | The name of the EKS cluster |
| cluster_endpoint | The EKS cluster endpoint    |

### Optional Variables

| Name                                          | Description                                                                                                     |
| --------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| enable_spot_termination                       | Determines whether to enable native spot termination handling. Default = false                                  |
| karpenter_sa_additional_iam_policies_arn_list | List of IAM policies ARN to attach with Karpenter ServiceAccount IAM role                                       |
| karpenter_serviceaccount_iam_role_name        | Custom name for ServiceAccount IAM role created by this module                                                  |
| cluster_ip_family                             | The IP family used to assign Kubernetes pod and service addresses. Valid values are `ipv4` (default) and `ipv6` |
| create_node_role                              | Create an IAM role or to use an existing IAM role for nodes that Karpenter provisions                           |
| node_role_additional_iam_policies_arn_list    | List of IAM policies ARN to attach with node role                                                               |
| custom_node_role_name                         | Name of custom created IAM role, to attach with nodes that Karpenter provisions                                 |

### Example config

> Check the `example` folder in this repo

### Outputs

| Name                                           | Description                          |
| ---------------------------------------------- | ------------------------------------ |
| karpenter_node_instance_profile_name           | Node Instance profile name           |
| karpenter_node_iam_role_arn                    | Node IAM role ARN                    |
| karpenter_node_spot_termination_sqs_queue_name | Node spot termination SQS queue name |
| karpenter_node_spot_termination_sqs_queue_id   | Node spot termination SQS queue ID   |
| karpenter_node_spot_termination_sqs_queue_arn  | Node spot termination SQS queue ARN  |
