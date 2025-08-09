# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

# S3 Outputs
output "raw_bucket_name" {
  description = "Raw data bucket name"
  value       = module.s3.raw_bucket_name
}

output "processed_bucket_name" {
  description = "Processed data bucket name"
  value       = module.s3.processed_bucket_name
}

output "archive_bucket_name" {
  description = "Archive bucket name"
  value       = module.s3.archive_bucket_name
}

# Glue Outputs
output "glue_catalog_database_name" {
  description = "Glue catalog database name"
  value       = module.glue.catalog_database_name
}

output "glue_crawler_name" {
  description = "Glue crawler name"
  value       = module.glue.crawler_name
}

output "glue_etl_job_name" {
  description = "Glue ETL job name"
  value       = module.glue.etl_job_name
}

# EMR Outputs
# EMR Outputs - Commented out due to SubscriptionRequiredException
# output "emr_cluster_id" {
#   description = "EMR cluster ID"
#   value       = module.emr.cluster_id
# }
# 
# output "emr_master_public_dns" {
#   description = "EMR master node public DNS"
#   value       = module.emr.master_public_dns
# }

# Redshift Outputs - Commented out due to OptInRequired error
# output "redshift_cluster_id" {
#   description = "Redshift cluster ID"
#   value       = module.redshift.cluster_id
# }
# 
# output "redshift_endpoint" {
#   description = "Redshift cluster endpoint"
#   value       = module.redshift.endpoint
# }
# 
# output "redshift_database_name" {
#   description = "Redshift database name"
#   value       = module.redshift.database_name
# }
# 
# output "redshift_username" {
#   description = "Redshift master username"
#   value       = module.redshift.master_username
# }

# Data Lake URLs
output "raw_data_url" {
  description = "S3 URL for raw data"
  value       = "s3://${module.s3.raw_bucket_name}/"
}

output "processed_data_url" {
  description = "S3 URL for processed data"
  value       = "s3://${module.s3.processed_bucket_name}/"
}

output "athena_query_results_bucket" {
  description = "S3 bucket for Athena query results"
  value       = module.glue.athena_results_bucket
}
