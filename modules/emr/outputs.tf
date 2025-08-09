output "cluster_id" {
  description = "EMR cluster ID"
  value       = aws_emr_cluster.data_processing.id
}

output "cluster_name" {
  description = "EMR cluster name"
  value       = aws_emr_cluster.data_processing.name
}

output "master_public_dns" {
  description = "EMR master node public DNS"
  value       = aws_emr_cluster.data_processing.master_public_dns
}

output "cluster_arn" {
  description = "EMR cluster ARN"
  value       = aws_emr_cluster.data_processing.arn
}

output "service_role_arn" {
  description = "EMR service role ARN"
  value       = aws_iam_role.emr_service_role.arn
}
