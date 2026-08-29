terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket       = "number-reverser-tfstate-598907064200"
    key          = "number-reverser/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
