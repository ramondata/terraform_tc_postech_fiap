# Provider
provider "aws" {
  region = "us-east-1"
}

# VPC
module "vpc" {
  source          = "./vpc"
  env             = var.env
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  azs             = var.azs
}

# EKS
module "eks" {
  source          = "./eks"
  env             = var.env
  cluster_version = var.cluster_version
  cluster_name    = var.cluster_name

  subnet_ids = module.vpc.private_subnet_ids

  node_instance_types = var.node_instance_types
  desired_size        = var.desired_size
  min_size            = var.min_size
  max_size            = var.max_size
}

# ECR
module "ecr" {
  source = "./ecr"
}