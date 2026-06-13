# =============================================================================
# IAM Role — Shared execution role for all claim pipeline Lambda functions
# =============================================================================

resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-exec-role"

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

resource "aws_iam_policy" "lambda_permissions" {
  name        = "${var.project_name}-lambda-policy"
  description = "Permissions for claims pipeline Lambda functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.claims_store.arn,
          "${aws_dynamodb_table.claims_store.arn}/index/*"
        ]
      },
      {
        Sid    = "EventBridgePublish"
        Effect = "Allow"
        Action = [
          "events:PutEvents"
        ]
        Resource = aws_cloudwatch_event_bus.claims_bus.arn
      },
      {
        Sid    = "SNSPublish"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [
          aws_sns_topic.claim_status_notifications.arn,
          aws_sns_topic.fraud_alerts.arn
        ]
      },
      {
        Sid    = "SQSAccess"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          aws_sqs_queue.claims_processing.arn,
          aws_sqs_queue.fraud_detection.arn,
          aws_sqs_queue.notification.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_permissions.arn
}

# =============================================================================
# Lambda Packages (zip archives)
# =============================================================================

data "archive_file" "claims_processor_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/claims_processor/index.py"
  output_path = "${path.module}/../lambda/claims_processor/claims_processor.zip"
}

data "archive_file" "fraud_detector_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/fraud_detector/index.py"
  output_path = "${path.module}/../lambda/fraud_detector/fraud_detector.zip"
}

data "archive_file" "notification_sender_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/notification_sender/index.py"
  output_path = "${path.module}/../lambda/notification_sender/notification_sender.zip"
}

data "archive_file" "analytics_ingester_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/analytics_ingester/index.py"
  output_path = "${path.module}/../lambda/analytics_ingester/analytics_ingester.zip"
}

# =============================================================================
# Lambda Functions — 4 independent event consumers
# =============================================================================

resource "aws_lambda_function" "claims_processor" {
  filename         = data.archive_file.claims_processor_zip.output_path
  source_code_hash = data.archive_file.claims_processor_zip.output_base64sha256
  function_name    = "${var.project_name}-claims-processor"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "python3.11"
  timeout          = 30

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.claims_store.name
      EVENT_BUS_NAME = aws_cloudwatch_event_bus.claims_bus.name
    }
  }

  tags = {
    Environment = var.environment
    Component   = "ClaimsProcessor"
  }
}

resource "aws_lambda_function" "fraud_detector" {
  filename         = data.archive_file.fraud_detector_zip.output_path
  source_code_hash = data.archive_file.fraud_detector_zip.output_base64sha256
  function_name    = "${var.project_name}-fraud-detector"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "python3.11"
  timeout          = 60 # Longer timeout for ML model inference

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.claims_store.name
      EVENT_BUS_NAME = aws_cloudwatch_event_bus.claims_bus.name
    }
  }

  tags = {
    Environment = var.environment
    Component   = "FraudDetector"
  }
}

resource "aws_lambda_function" "notification_sender" {
  filename         = data.archive_file.notification_sender_zip.output_path
  source_code_hash = data.archive_file.notification_sender_zip.output_base64sha256
  function_name    = "${var.project_name}-notification-sender"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "python3.11"
  timeout          = 15

  environment {
    variables = {
      SNS_TOPIC_ARN       = aws_sns_topic.claim_status_notifications.arn
      FRAUD_SNS_TOPIC_ARN = aws_sns_topic.fraud_alerts.arn
      TEAMS_WEBHOOK_URL   = var.teams_webhook_url
    }
  }

  tags = {
    Environment = var.environment
    Component   = "NotificationSender"
  }
}

resource "aws_lambda_function" "analytics_ingester" {
  filename         = data.archive_file.analytics_ingester_zip.output_path
  source_code_hash = data.archive_file.analytics_ingester_zip.output_base64sha256
  function_name    = "${var.project_name}-analytics-ingester"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "python3.11"
  timeout          = 15

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.claims_store.name
    }
  }

  tags = {
    Environment = var.environment
    Component   = "AnalyticsIngester"
  }
}
