# =============================================================================
# SQS Queues — Buffer events so each consumer processes at its own pace
# =============================================================================

# --- Claims Processing Queue ---
resource "aws_sqs_queue" "claims_processing_dlq" {
  name                      = "${var.project_name}-claims-processing-dlq"
  message_retention_seconds = 1209600 # 14 days retention for dead letters

  tags = {
    Environment = var.environment
    Purpose     = "Dead letter queue for failed claim processing messages"
  }
}

resource "aws_sqs_queue" "claims_processing" {
  name                       = "${var.project_name}-claims-processing"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400 # 1 day
  receive_wait_time_seconds  = 10    # Long polling for cost efficiency

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.claims_processing_dlq.arn
    maxReceiveCount     = 3 # After 3 failed attempts, move to DLQ
  })

  tags = {
    Environment = var.environment
    Purpose     = "Incoming claim events for validation and persistence"
  }
}

# --- Fraud Detection Queue ---
resource "aws_sqs_queue" "fraud_detection_dlq" {
  name                      = "${var.project_name}-fraud-detection-dlq"
  message_retention_seconds = 1209600

  tags = {
    Environment = var.environment
    Purpose     = "Dead letter queue for failed fraud detection messages"
  }
}

resource "aws_sqs_queue" "fraud_detection" {
  name                       = "${var.project_name}-fraud-detection"
  visibility_timeout_seconds = 120 # Longer timeout for ML model inference
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 10

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.fraud_detection_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Environment = var.environment
    Purpose     = "Validated claims queued for fraud scoring"
  }
}

# --- Notification Queue ---
resource "aws_sqs_queue" "notification_dlq" {
  name                      = "${var.project_name}-notification-dlq"
  message_retention_seconds = 1209600

  tags = {
    Environment = var.environment
    Purpose     = "Dead letter queue for failed notification deliveries"
  }
}

resource "aws_sqs_queue" "notification" {
  name                       = "${var.project_name}-notification"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 10

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notification_dlq.arn
    maxReceiveCount     = 5 # More retries for transient notification failures
  })

  tags = {
    Environment = var.environment
    Purpose     = "Member notifications (email, SMS, push) and Teams alerts"
  }
}
