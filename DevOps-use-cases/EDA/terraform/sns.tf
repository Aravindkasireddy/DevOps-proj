# =============================================================================
# SNS Topics — Fan-out notifications to multiple channels simultaneously
# =============================================================================

# --- Member Claim Status Notifications (Email, SMS, Push) ---
resource "aws_sns_topic" "claim_status_notifications" {
  name = "${var.project_name}-claim-status"

  tags = {
    Environment = var.environment
    Purpose     = "Fan-out claim status updates to member via email, SMS, and push"
  }
}

resource "aws_sns_topic_subscription" "claims_ops_email" {
  topic_arn = aws_sns_topic.claim_status_notifications.arn
  protocol  = "email"
  endpoint  = var.member_notification_email
}

# --- Fraud Alert Notifications (Internal Security Team) ---
resource "aws_sns_topic" "fraud_alerts" {
  name = "${var.project_name}-fraud-alerts"

  tags = {
    Environment = var.environment
    Purpose     = "Critical fraud detection alerts to the Special Investigations Unit (SIU)"
  }
}

resource "aws_sns_topic_subscription" "fraud_siu_email" {
  topic_arn = aws_sns_topic.fraud_alerts.arn
  protocol  = "email"
  endpoint  = "siu-investigations@usaa.com"
}
