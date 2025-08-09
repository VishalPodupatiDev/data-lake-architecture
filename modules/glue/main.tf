# Glue Catalog Database
resource "aws_glue_catalog_database" "data_lake" {
  name = "${var.project_name}_${var.environment}_catalog"

  tags = {
    Name        = "${var.project_name}-glue-catalog"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Glue Crawler Role
resource "aws_iam_role" "glue_crawler" {
  name = "${var.project_name}-${var.environment}-glue-crawler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-glue-crawler-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Glue Crawler Policy
resource "aws_iam_role_policy" "glue_crawler_policy" {
  name = "${var.project_name}-${var.environment}-glue-crawler-policy"
  role = aws_iam_role.glue_crawler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.raw_bucket_name}",
          "arn:aws:s3:::${var.raw_bucket_name}/*",
          "arn:aws:s3:::${var.processed_bucket_name}",
          "arn:aws:s3:::${var.processed_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Glue Crawler
resource "aws_glue_crawler" "raw_data" {
  name          = "${var.project_name}-${var.environment}-raw-crawler"
  database_name = aws_glue_catalog_database.data_lake.name
  role          = aws_iam_role.glue_crawler.arn

  s3_target {
    path = "s3://${var.raw_bucket_name}/"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
      Tables     = { AddOrUpdateBehavior = "MergeNewColumns" }
    }
  })

  tags = {
    Name        = "${var.project_name}-raw-crawler"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Glue ETL Job Role
resource "aws_iam_role" "glue_job" {
  name = "${var.project_name}-${var.environment}-glue-job-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-glue-job-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Glue Job Policy
resource "aws_iam_role_policy" "glue_job_policy" {
  name = "${var.project_name}-${var.environment}-glue-job-policy"
  role = aws_iam_role.glue_job.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.raw_bucket_name}",
          "arn:aws:s3:::${var.raw_bucket_name}/*",
          "arn:aws:s3:::${var.processed_bucket_name}",
          "arn:aws:s3:::${var.processed_bucket_name}/*",
          "arn:aws:s3:::${var.archive_bucket_name}",
          "arn:aws:s3:::${var.archive_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Glue ETL Job
resource "aws_glue_job" "etl_job" {
  name     = "${var.project_name}-${var.environment}-etl-job"
  role_arn = aws_iam_role.glue_job.arn

  command {
    script_location = "s3://${var.raw_bucket_name}/scripts/glue_etl_job.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language" = "python"
    "--job-bookmark-option" = "job-bookmark-enable"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics" = "true"
    "--raw_bucket" = var.raw_bucket_name
    "--processed_bucket" = var.processed_bucket_name
    "--archive_bucket" = var.archive_bucket_name
  }

  execution_property {
    max_concurrent_runs = 1
  }

  max_retries = 0
  timeout     = 2880

  glue_version = "4.0"

  tags = {
    Name        = "${var.project_name}-etl-job"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Glue Workflow
resource "aws_glue_workflow" "data_pipeline" {
  name = "${var.project_name}-${var.environment}-workflow"

  tags = {
    Name        = "${var.project_name}-workflow"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Glue Trigger for ETL Job
resource "aws_glue_trigger" "etl_trigger" {
  name          = "${var.project_name}-${var.environment}-etl-trigger"
  workflow_name = aws_glue_workflow.data_pipeline.name
  type          = "CONDITIONAL"

  actions {
    job_name = aws_glue_job.etl_job.name
  }

  predicate {
    conditions {
      job_name = aws_glue_crawler.raw_data.name
      state    = "SUCCEEDED"
    }
  }

  tags = {
    Name        = "${var.project_name}-etl-trigger"
    Environment = var.environment
    Project     = var.project_name
  }
}
