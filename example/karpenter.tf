data "aws_ami" "latest_eks_bottlerocket" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["bottlerocket-aws-k8s-1.23-x86_64-*"]
  }
}
  
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.13"

  cluster_name = "thecluster"
  # ....
  # ...... other attributes
  # .......

}

module "karpenter" {
  source  = "bigfantech-cloud/karpenter/k8s"
  version = "1.0.0"

  cluster_name            = module.eks.cluster_name
  cluster_endpoint        = module.eks.cluster_endpoint
  enable_spot_termination = false
  karpenter_sa_additional_iam_policies_arn_list = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

resource "aws_launch_template" "karpenter_cpu" {
  name                   = "karpenter-provisioning-node"
  description            = "EKS Karpenter provisioning node Launch-Template"
  update_default_version = true
  key_name               = "thekeypair"
  image_id               = data.aws_ami.latest_eks_bottlerocket.image_id
  vpc_security_group_ids = [module.eks.cluster_primary_security_group_id]

  iam_instance_profile {
    name = module.karpenter.karpenter_node_instance_profile_name
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 50
      encrypted   = "true"
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      module.this.tags,
      {
        Name = "eks-cpu"
      }
    )
  }
}

data "kubectl_path_documents" "karpenter" {
  pattern = "${path.module}/values/*.yaml"
}

resource "kubectl_manifest" "karpenter" {
  for_each  = data.kubectl_path_documents.karpenter.manifests
  yaml_body = each.value
}
