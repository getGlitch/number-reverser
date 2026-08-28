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
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git?ref=a0307d4"

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
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = {
    Project     = "number-reverser"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

module "eks" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-eks.git?ref=48a429f63cf96361ea2f4b42677d0cc8a9a656e0"

  name               = local.name
  kubernetes_version = "1.33"

  endpoint_public_access  = true
  endpoint_private_access = true

  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enabled_log_types = [
    "api",
    "audit",
    "authenticator"
  ]

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
