variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnets" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for EMR"
  type        = string
}

variable "raw_bucket_name" {
  description = "Raw data bucket name"
  type        = string
}

variable "processed_bucket_name" {
  description = "Processed data bucket name"
  type        = string
}

variable "emr_instance_type" {
  description = "EMR instance type"
  type        = string
  default     = "m5.xlarge"
}

variable "emr_instance_count" {
  description = "Number of EMR instances"
  type        = number
  default     = 3
}
