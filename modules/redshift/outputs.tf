output "cluster_id" {
  description = "Redshift cluster ID"
  value       = aws_redshift_cluster.main.cluster_identifier
}

output "endpoint" {
  description = "Redshift cluster endpoint"
  value       = aws_redshift_cluster.main.endpoint
}

output "database_name" {
  description = "Redshift database name"
  value       = aws_redshift_cluster.main.database_name
}

output "master_username" {
  description = "Redshift master username"
  value       = aws_redshift_cluster.main.master_username
}

output "master_password" {
  description = "Redshift master password"
  value       = random_password.redshift_password.result
  sensitive   = true
}

output "cluster_arn" {
  description = "Redshift cluster ARN"
  value       = aws_redshift_cluster.main.arn
}

output "s3_role_arn" {
  description = "Redshift S3 access role ARN"
  value       = aws_iam_role.redshift_s3_access.arn
}
