# EMR Cluster
resource "aws_emr_cluster" "data_processing" {
  name          = "${var.project_name}-${var.environment}-cluster"
  release_label = "emr-6.15.0"
  applications  = ["Spark", "Hadoop", "Hive"]

  termination_protection            = false
  keep_job_flow_alive_when_no_steps = false

  ec2_attributes {
    subnet_id                         = var.private_subnets[0]
    emr_managed_master_security_group = var.security_group_id
    emr_managed_slave_security_group  = var.security_group_id
    instance_profile                  = aws_iam_instance_profile.emr_profile.arn
  }

  master_instance_group {
    instance_type = var.emr_instance_type
  }

  core_instance_group {
    instance_type  = var.emr_instance_type
    instance_count = var.emr_instance_count

    ebs_config {
      size                 = 100
      type                 = "gp2"
      volumes_per_instance = 1
    }
  }

  configurations_json = <<EOF
  [
    {
      "Classification": "spark-defaults",
      "Properties": {
        "spark.driver.memory": "5g",
        "spark.executor.memory": "5g",
        "spark.executor.cores": "4",
        "spark.dynamicAllocation.enabled": "true",
        "spark.dynamicAllocation.minExecutors": "1",
        "spark.dynamicAllocation.maxExecutors": "10"
      }
    },
    {
      "Classification": "hive-site",
      "Properties": {
        "hive.metastore.client.factory.class": "com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory"
      }
    }
  ]
EOF

  log_uri = "s3://${var.processed_bucket_name}/emr-logs/"

  service_role = aws_iam_role.emr_service_role.arn
  autoscaling_role = aws_iam_role.emr_autoscaling_role.arn

  tags = {
    Name        = "${var.project_name}-emr-cluster"
    Environment = var.environment
    Project     = var.project_name
  }
}

# EMR Instance Group Configuration
resource "aws_emr_instance_group" "task" {
  cluster_id     = aws_emr_cluster.data_processing.id
  instance_count = 2
  instance_type  = var.emr_instance_type

  configurations_json = <<EOF
  [
    {
      "Classification": "spark-defaults",
      "Properties": {
        "spark.executor.memory": "5g",
        "spark.executor.cores": "4"
      }
    }
  ]
EOF

  ebs_config {
    size                 = 100
    type                 = "gp2"
    volumes_per_instance = 1
  }

  bid_price = "0.1" # Spot instance pricing
}

# IAM Service Role for EMR
resource "aws_iam_role" "emr_service_role" {
  name = "${var.project_name}-${var.environment}-emr-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "elasticmapreduce.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-emr-service-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Attach EMR service role policy
resource "aws_iam_role_policy_attachment" "emr_service_role" {
  role       = aws_iam_role.emr_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"
}

# IAM Instance Profile Role for EMR
resource "aws_iam_role" "emr_instance_profile_role" {
  name = "${var.project_name}-${var.environment}-emr-instance-profile-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-emr-instance-profile-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Attach EMR instance profile role policy
resource "aws_iam_role_policy_attachment" "emr_instance_profile_role" {
  role       = aws_iam_role.emr_instance_profile_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
}

# Additional S3 access policy for EMR instances
resource "aws_iam_role_policy" "emr_s3_policy" {
  name = "${var.project_name}-${var.environment}-emr-s3-policy"
  role = aws_iam_role.emr_instance_profile_role.id

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
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "emr_profile" {
  name = "${var.project_name}-${var.environment}-emr-instance-profile"
  role = aws_iam_role.emr_instance_profile_role.name
}

# IAM Autoscaling Role for EMR
resource "aws_iam_role" "emr_autoscaling_role" {
  name = "${var.project_name}-${var.environment}-emr-autoscaling-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "elasticmapreduce.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-emr-autoscaling-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Attach autoscaling role policy
resource "aws_iam_role_policy_attachment" "emr_autoscaling_role" {
  role       = aws_iam_role.emr_autoscaling_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforAutoScalingRole"
}
