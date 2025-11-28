terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider configuration moved to provider_local.tf for simulation


# --- S3 Bucket for Salesforce Data ---
resource "aws_s3_bucket" "data_bucket" {
  bucket_prefix = "${var.project_name}-data-"
  force_destroy = true
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.data_bucket.id
  eventbridge = true
}

# --- IAM Roles ---

# AppFlow Role
resource "aws_iam_role" "appflow_role" {
  name = "${var.project_name}-appflow-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "appflow.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "appflow_s3_policy" {
  name = "${var.project_name}-appflow-s3-policy"
  role = aws_iam_role.appflow_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetBucketAcl",
          "s3:PutObjectAcl"
        ]
        Resource = [
          aws_s3_bucket.data_bucket.arn,
          "${aws_s3_bucket.data_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Lambda Role
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "${var.project_name}-lambda-s3-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "${aws_s3_bucket.data_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Step Functions Role
resource "aws_iam_role" "sfn_role" {
  name = "${var.project_name}-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "sfn_lambda_policy" {
  name = "${var.project_name}-sfn-lambda-policy"
  role = aws_iam_role.sfn_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.processor_lambda.arn
        ]
      }
    ]
  })
}

# EventBridge Role (to invoke Step Function)
resource "aws_iam_role" "eventbridge_role" {
  name = "${var.project_name}-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "eventbridge_sfn_policy" {
  name = "${var.project_name}-eventbridge-sfn-policy"
  role = aws_iam_role.eventbridge_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = [
          aws_sfn_state_machine.orchestrator.arn
        ]
      }
    ]
  })
}


# --- AppFlow Flow ---
resource "aws_appflow_flow" "salesforce_flow" {
  name = "${var.project_name}-salesforce-flow"
  description = "Flow to sync Salesforce data to S3"

  source_flow_config {
    connector_type = "Salesforce"
    connector_profile_name = var.salesforce_connector_profile_name
    source_connector_properties {
      salesforce {
        object = var.salesforce_object
      }
    }
  }

  destination_flow_config {
    connector_type = "S3"
    destination_connector_properties {
      s3 {
        bucket_name = aws_s3_bucket.data_bucket.bucket
        s3_output_format_config {
          aggregation_config {
            aggregation_type = "None"
          }
        }
      }
    }
  }

  trigger_config {
    trigger_type = "OnDemand" # Can be changed to Scheduled
  }

  task {
    source_fields     = ["Id", "Name"] # Example fields, adjust as needed
    destination_field = "Id"
    task_type         = "Map"
    connector_operator {
      salesforce = "NO_OP"
    }
  }
   task {
    source_fields     = ["Name"] 
    destination_field = "Name"
    task_type         = "Map"
    connector_operator {
      salesforce = "NO_OP"
    }
  }
}

# --- Lambda Function ---
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../dist" # Assumes 'npm run build' has run
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "processor_lambda" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "${var.project_name}-processor"
  role          = aws_iam_role.lambda_role.arn
  handler       = "processor.handler"
  runtime       = "nodejs22.x" # Using Node 22 as requested
  timeout       = 30

  environment {
    variables = {
      EXTERNAL_API_URL = var.external_api_url
    }
  }

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

# --- Step Function ---
resource "aws_sfn_state_machine" "orchestrator" {
  name     = "${var.project_name}-orchestrator"
  role_arn = aws_iam_role.sfn_role.arn

  definition = jsonencode({
    Comment = "Orchestrate S3 event to Lambda"
    StartAt = "ProcessFile"
    States = {
      ProcessFile = {
        Type = "Task"
        Resource = aws_lambda_function.processor_lambda.arn
        End = true
      }
    }
  })
}

# --- EventBridge Rule ---
resource "aws_cloudwatch_event_rule" "s3_upload_rule" {
  name        = "${var.project_name}-s3-upload-rule"
  description = "Trigger Step Function when file is uploaded to S3"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.data_bucket.bucket]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "sfn_target" {
  rule      = aws_cloudwatch_event_rule.s3_upload_rule.name
  target_id = "SendToStepFunction"
  arn       = aws_sfn_state_machine.orchestrator.arn
  role_arn  = aws_iam_role.eventbridge_role.arn
}
