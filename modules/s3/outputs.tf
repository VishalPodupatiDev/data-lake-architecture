output "raw_bucket_name" {
  description = "Raw data bucket name"
  value       = aws_s3_bucket.raw.bucket
}

output "processed_bucket_name" {
  description = "Processed data bucket name"
  value       = aws_s3_bucket.processed.bucket
}

output "archive_bucket_name" {
  description = "Archive bucket name"
  value       = aws_s3_bucket.archive.bucket
}

output "athena_results_bucket_name" {
  description = "Athena results bucket name"
  value       = aws_s3_bucket.athena_results.bucket
}

output "glue_s3_role_arn" {
  description = "Glue S3 access role ARN"
  value       = aws_iam_role.glue_s3_access.arn
}
