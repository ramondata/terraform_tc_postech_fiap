# Provider
provider "aws" {
  region = var.region
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

# RDS
module "rds" {
  rds_databases = var.rds_databases

  source = "./rds"
  env    = var.env
  #db_name              = each.value
  private_subnet_ids   = module.vpc.private_subnet_ids
  db_username          = var.db_username
  db_password          = var.db_password
  vpc_id               = module.vpc.vpc_id
  db_engine            = var.engine
  db_engine_version    = var.engine_version
  db_instance_class    = var.instance_class
  db_allocated_storage = var.allocated_storage
}

# elasticache
module "elasticache" {
  source             = "./elasticache"
  private_subnet_ids = module.vpc.private_subnet_ids
  env                = var.env
}

# dynamodb
module "dynamodb" {
  source       = "./dynamodb"
  env          = var.env
  dynamodb_key = var.dynamodb_key
}

# SQS
module "sqs" {
  source   = "./sqs"
  name_sqs = var.name_sqs
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
  source                = "./ecr"
  aws_oidc_provider_arn = var.aws_oidc_provider_arn
  repositories          = var.repositories
}