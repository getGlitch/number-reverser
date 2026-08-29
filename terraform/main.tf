data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "number-reverser"

  azs = slice(
    data.aws_availability_zones.available.names,
    0,
    2
  )
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = local.name
  cidr = "10.0.0.0/16"

  azs = local.azs

  private_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]

  public_subnets = [
    "10.0.101.0/24",
    "10.0.102.0/24"
  ]

  enable_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  manage_default_security_group = true

  default_security_group_ingress = []
  default_security_group_egress  = []

  tags = {
    Project     = "number-reverser"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.name
  kubernetes_version = "1.33"

  endpoint_public_access  = true
  endpoint_private_access = true

  #  enable_cluster_creator_admin_permissions = true

  enable_cluster_creator_admin_permissions = false

  access_entries = {
    cluster_creator = {
      principal_arn = "arn:aws:iam::598907064200:root"

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

          access_scope = {
            type = "cluster"
          }
        }
      }
    }

    github_actions = {
      principal_arn = "arn:aws:iam::598907064200:role/GitHubActions-NumberReverser"

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  kms_key_administrators = [
    "arn:aws:iam::598907064200:root"
  ]

  addons = {
    vpc-cni = {
      before_compute = true
      most_recent    = true
    }

    kube-proxy = {
      most_recent = true
    }

    coredns = {
      most_recent = true
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  create_cni_ipv6_iam_policy = false

  enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  encryption_config = {
    resources = ["secrets"]
  }

  cloudwatch_log_group_retention_in_days = 365

  eks_managed_node_groups = {
    default = {
      name = "number-reverser-ng"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 2
      desired_size = 1

      subnet_ids = module.vpc.private_subnets

      capacity_type = "ON_DEMAND"

      disk_size = 20

      labels = {
        Environment = "dev"
        Application = "number-reverser"
      }

      tags = {
        Project     = "number-reverser"
        Environment = "dev"
        ManagedBy   = "Terraform"
      }
    }
  }

  tags = {
    Project     = "number-reverser"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
