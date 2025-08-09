output "catalog_database_name" {
  description = "Glue catalog database name"
  value       = aws_glue_catalog_database.data_lake.name
}

output "crawler_name" {
  description = "Glue crawler name"
  value       = aws_glue_crawler.raw_data.name
}

output "etl_job_name" {
  description = "Glue ETL job name"
  value       = aws_glue_job.etl_job.name
}

output "workflow_name" {
  description = "Glue workflow name"
  value       = aws_glue_workflow.data_pipeline.name
}

output "glue_job_role_arn" {
  description = "Glue job role ARN"
  value       = aws_iam_role.glue_job.arn
}

output "athena_results_bucket" {
  description = "Athena results bucket name"
  value       = "s3://${var.processed_bucket_name}/athena-results/"
}
