terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC and Networking
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr             = var.vpc_cidr
  environment          = var.environment
  project_name         = var.project_name
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
}

# S3 Storage Layer
module "s3" {
  source = "./modules/s3"
  
  environment     = var.environment
  project_name    = var.project_name
  aws_region      = var.aws_region
  account_id      = var.account_id
}

# Glue ETL and Catalog
module "glue" {
  source = "./modules/glue"
  
  environment     = var.environment
  project_name    = var.project_name
  aws_region      = var.aws_region
  account_id      = var.account_id
  
  raw_bucket_name     = module.s3.raw_bucket_name
  processed_bucket_name = module.s3.processed_bucket_name
  archive_bucket_name   = module.s3.archive_bucket_name
  
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnet_ids
  security_group_id = module.vpc.glue_security_group_id
}

# EMR Processing Cluster - Commented out due to SubscriptionRequiredException
# module "emr" {
#   source = "./modules/emr"
#   
#   environment     = var.environment
#   project_name    = var.project_name
#   aws_region      = var.aws_region
#   
#   vpc_id          = module.vpc.vpc_id
#   private_subnets = module.vpc.private_subnet_ids
#   security_group_id = module.vpc.emr_security_group_id
#   
#   raw_bucket_name     = module.s3.raw_bucket_name
#   processed_bucket_name = module.s3.processed_bucket_name
#
#   emr_instance_type  = var.emr_instance_type
#   emr_instance_count = var.emr_instance_count
# }

# Redshift Data Warehouse - Commented out due to OptInRequired error
# module "redshift" {
#   source = "./modules/redshift"
#   
#   environment     = var.environment
#   project_name    = var.project_name
#   aws_region      = var.aws_region
#   account_id      = var.account_id
#   
#   vpc_id          = module.vpc.vpc_id
#   private_subnets = module.vpc.private_subnet_ids
#   security_group_id = module.vpc.redshift_security_group_id
#   
#   processed_bucket_name = module.s3.processed_bucket_name
#   redshift_node_type  = var.redshift_node_type
#   redshift_node_count = var.redshift_node_count
# }
