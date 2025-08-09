# Redshift Subnet Group
resource "aws_redshift_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-redshift-subnet-group"
  subnet_ids = var.private_subnets

  tags = {
    Name        = "${var.project_name}-redshift-subnet-group"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Redshift Parameter Group
resource "aws_redshift_parameter_group" "main" {
  name   = "${var.project_name}-${var.environment}-redshift-params"
  family = "redshift-1.0"

  parameter {
    name  = "wlm_json_configuration"
    value = jsonencode([
      {
        query_group = []
        user_group  = []
        query_slot_count = 5
        auto_wlm = true
      }
    ])
  }

  parameter {
    name  = "enable_user_activity_logging"
    value = "true"
  }

  parameter {
    name  = "max_concurrency_scaling_clusters"
    value = "1"
  }

  tags = {
    Name        = "${var.project_name}-redshift-params"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Redshift Cluster
resource "aws_redshift_cluster" "main" {
  cluster_identifier        = "${var.project_name}-${var.environment}-cluster"
  database_name            = "datalake"
  master_username          = "admin"
  master_password          = random_password.redshift_password.result
  node_type               = var.redshift_node_type
  cluster_type            = "multi-node"
  number_of_nodes         = var.redshift_node_count
  skip_final_snapshot     = true
  automated_snapshot_retention_period = 7

  vpc_security_group_ids = [var.security_group_id]

  logging {
    enable        = true
    bucket_name   = var.processed_bucket_name
    s3_key_prefix = "redshift-logs/"
  }

  tags = {
    Name        = "${var.project_name}-redshift-cluster"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Random password for Redshift
resource "random_password" "redshift_password" {
  length  = 16
  special = true
}

# IAM Role for Redshift to access S3
resource "aws_iam_role" "redshift_s3_access" {
  name = "${var.project_name}-${var.environment}-redshift-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "redshift.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-redshift-s3-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM Policy for Redshift S3 access
resource "aws_iam_role_policy" "redshift_s3_policy" {
  name = "${var.project_name}-${var.environment}-redshift-s3-policy"
  role = aws_iam_role.redshift_s3_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.processed_bucket_name}",
          "arn:aws:s3:::${var.processed_bucket_name}/*"
        ]
      }
    ]
  })
}

# Attach Redshift S3 role to cluster
resource "aws_redshift_cluster_iam_roles" "main" {
  cluster_identifier = aws_redshift_cluster.main.cluster_identifier
  iam_role_arns     = [aws_iam_role.redshift_s3_access.arn]
}

# Redshift Endpoint Access
resource "aws_redshift_endpoint_access" "main" {
  endpoint_name      = "redshift-endpoint"
  cluster_identifier = aws_redshift_cluster.main.cluster_identifier
  subnet_group_name  = aws_redshift_subnet_group.main.name
}

# CloudWatch Log Group for Redshift
resource "aws_cloudwatch_log_group" "redshift_logs" {
  name              = "/aws/redshift/cluster/${aws_redshift_cluster.main.cluster_identifier}"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-redshift-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}
