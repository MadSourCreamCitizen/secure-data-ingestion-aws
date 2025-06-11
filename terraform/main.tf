# main.tf

# This 'terraform' block configures Terraform itself.
# It declares the providers required for this configuration.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

# This 'provider' block configures the AWS Provider with your chosen region.
provider "aws" {
  region = "us-east-1" # Replace with your AWS region
}

# Resource: Random string for unique bucket naming
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# Resource: S3 Bucket for Raw Patient Data
resource "aws_s3_bucket" "raw_data_bucket" {
  bucket = "secure-patient-data-${random_id.bucket_suffix.hex}"

  tags = {
    Project     = "SecureHealthcarePipeline"
    Environment = "Dev"
    Purpose     = "RawPatientDataIngestion"
  }
}

# Resource: S3 Bucket Versioning Configuration for Raw Data
resource "aws_s3_bucket_versioning" "raw_data_bucket_versioning" {
  bucket = aws_s3_bucket.raw_data_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Resource: Block all public access to the S3 bucket (CRITICAL for security)
resource "aws_s3_bucket_public_access_block" "raw_data_bucket_public_access_block" {
  bucket = aws_s3_bucket.raw_data_bucket.id

  block_public_acls       = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  block_public_policy     = true
}

# Resource: AWS KMS Key for Data Encryption
resource "aws_kms_key" "patient_data_key" {
  description             = "KMS key for encrypting patient data in S3"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = data.aws_caller_identity.current.arn # This is your current user/role running Terraform
        },
        Action = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "Allow S3 to use KMS key",
        Effect = "Allow",
        Principal = {
          Service = "s3.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*",
        Condition = {
          StringEquals = {
            "kms:ViaService" : "s3.${var.aws_region}.amazonaws.com"
          },
          "StringLike" : {
            "kms:EncryptionContext:aws:s3:arn" : [
              aws_s3_bucket.raw_data_bucket.arn
            ]
          }
        }
      },
      # NEW: Allow Lambda's execution role to use this KMS key for decryption
      {
        Sid    = "Allow Lambda Role to Use KMS Key",
        Effect = "Allow",
        Principal = {
          AWS = aws_iam_role.lambda_exec_role.arn # This explicitly grants access to the Lambda's role
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*" # Applies to this specific KMS key
      }
    ]
  })
}

# Resource: Enforce Server-Side Encryption using the KMS key on the S3 bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "raw_data_encryption" {
  bucket = aws_s3_bucket.raw_data_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.patient_data_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Resource: S3 Bucket for Processed Patient Data
resource "aws_s3_bucket" "processed_data_bucket" {
  bucket = "secure-processed-data-${random_id.bucket_suffix.hex}"

  tags = {
    Project     = "SecureHealthcarePipeline"
    Environment = "Dev"
    Purpose     = "ProcessedPatientDataStorage"
  }
}

# Resource: S3 Bucket Versioning Configuration for Processed Data
resource "aws_s3_bucket_versioning" "processed_data_bucket_versioning" {
  bucket = aws_s3_bucket.processed_data_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Resource: Block all public access to the Processed S3 bucket (CRITICAL for security)
resource "aws_s3_bucket_public_access_block" "processed_data_bucket_public_access_block" {
  bucket = aws_s3_bucket.processed_data_bucket.id

  block_public_acls       = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  block_public_policy     = true
}

# Resource: IAM Role for Lambda Function
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-patient-data-processor-role-${random_id.bucket_suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Project = "SecureHealthcarePipeline"
  }
}

# Resource: IAM Policy for Lambda Function
resource "aws_iam_role_policy" "lambda_exec_policy" {
  name = "lambda-exec-policy-${random_id.bucket_suffix.hex}"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*:*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:GetObjectAcl",
          "s3:GetObjectVersion"
        ],
        Resource = "${aws_s3_bucket.raw_data_bucket.arn}/*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ],
        Resource = "${aws_s3_bucket.processed_data_bucket.arn}/*"
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*"
        ],
        Resource = aws_kms_key.patient_data_key.arn
      }
    ]
  })
}

# Data Source: Archive Lambda Function Code into a Zip File
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/data_processor"
  output_path = "${path.module}/data_processor_lambda.zip"
}

# Resource: AWS Lambda Function
resource "aws_lambda_function" "data_processor_lambda" {
  function_name    = "SecurePatientDataProcessor-${random_id.bucket_suffix.hex}"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  timeout          = 60
  memory_size      = 128

  environment {
    variables = {
      PROCESSED_BUCKET_NAME = aws_s3_bucket.processed_data_bucket.bucket
      KMS_KEY_ARN           = aws_kms_key.patient_data_key.arn
    }
  }

  tags = {
    Project = "SecureHealthcarePipeline"
  }
}

# Resource: Lambda Permission for S3 to Invoke
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowS3InvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_processor_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw_data_bucket.arn
  depends_on    = [aws_s3_bucket_notification.raw_data_bucket_notification] # Explicit dependency for safety
}

# Resource: S3 Bucket Notification for Raw Data to Trigger Lambda
resource "aws_s3_bucket_notification" "raw_data_bucket_notification" {
  bucket = aws_s3_bucket.raw_data_bucket.id

  lambda_function {
    id                  = "raw-data-processor-trigger"
    lambda_function_arn = aws_lambda_function.data_processor_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix = "raw/"
  }
}


# Data Source: Get current AWS account ID and ARN
data "aws_caller_identity" "current" {}

# Variable for AWS Region
variable "aws_region" {
  description = "The AWS region to deploy resources into."
  type        = string
  default     = "us-east-1" # Replace with your AWS region
}

# Output: Display the created S3 bucket name
output "raw_data_bucket_name" {
  description = "The name of the S3 bucket for raw patient data"
  value       = aws_s3_bucket.raw_data_bucket.bucket
}

# Output: Display the KMS Key ARN
output "patient_data_kms_key_arn" {
  description = "The ARN of the KMS key used for patient data encryption"
  value       = aws_kms_key.patient_data_key.arn
}

# NEW Output for Processed Bucket
output "processed_data_bucket_name" {
  description = "The name of the S3 bucket for processed patient data"
  value       = aws_s3_bucket.processed_data_bucket.bucket
}

# NEW Output for Lambda Function Name
output "lambda_function_name" {
  description = "The name of the patient data processor Lambda function"
  value       = aws_lambda_function.data_processor_lambda.function_name
}