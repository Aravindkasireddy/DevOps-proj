# =============================================================================
# Custom Event Bus — All claim events flow through this central bus
# =============================================================================
resource "aws_cloudwatch_event_bus" "claims_bus" {
  name = "${var.project_name}-event-bus"
  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
}

# =============================================================================
# Rule 1: ClaimFiled → Claims Processor Lambda
# =============================================================================
resource "aws_cloudwatch_event_rule" "claim_filed" {
  name           = "${var.project_name}-claim-filed"
  description    = "Routes ClaimFiled events to the claims processor for validation and persistence"
  event_bus_name = aws_cloudwatch_event_bus.claims_bus.name

  event_pattern = jsonencode({
    source      = ["usaa.claims.mobile-app"]
    detail-type = ["ClaimFiled"]
  })
}

resource "aws_cloudwatch_event_target" "claim_filed_to_processor" {
  rule           = aws_cloudwatch_event_rule.claim_filed.name
  event_bus_name = aws_cloudwatch_event_bus.claims_bus.name
  target_id      = "SendToClaimsProcessor"
  arn            = aws_lambda_function.claims_processor.arn
}

# =============================================================================
# Rule 2: ClaimValidated → Fraud Detector Lambda
# =============================================================================
resource "aws_cloudwatch_event_rule" "claim_validated" {
  name           = "${var.project_name}-claim-validated"
  description    = "Routes ClaimValidated events to the fraud detection engine"
  event_bus_name = aws_cloudwatch_event_bus.claims_bus.name

  event_pattern = jsonencode({
    source      = ["usaa.claims.processor"]
    detail-type = ["ClaimValidated"]
  })
}

resource "aws_cloudwatch_event_target" "claim_validated_to_fraud" {
  rule           = aws_cloudwatch_event_rule.claim_validated.name
  event_bus_name = aws_cloudwatch_event_bus.claims_bus.name
  target_id      = "SendToFraudDetector"
  arn            = aws_lambda_function.fraud_detector.arn
}

# =============================================================================
# Rule 3: ClaimApproved / FraudDetected → Notification Sender Lambda
# =============================================================================
resource "aws_cloudwatch_event_rule" "claim_status_change" {
  name           = "${var.project_name}-claim-status-change"
  description    = "Routes all claim status change events to the notification service"
  event_bus_name = aws_cloudwatch_event_bus.claims_bus.name

  event_pattern = jsonencode({
    source      = ["usaa.claims.fraud-detector"]
    detail-type = ["ClaimApproved", "ClaimFlaggedForReview", "FraudDetected"]
  })
}

resource "aws_cloudwatch_event_target" "status_to_notification" {
  rule           = aws_cloudwatch_event_rule.claim_status_change.name
  event_bus_name = aws_cloudwatch_event_bus.claims_bus.name
  target_id      = "SendToNotificationSender"
  arn            = aws_lambda_function.notification_sender.arn
}

# =============================================================================
# Rule 4: ALL events → Analytics Ingester Lambda (catch-all for data lake)
# =============================================================================
resource "aws_cloudwatch_event_rule" "all_claim_events" {
  name           = "${var.project_name}-all-events-analytics"
  description    = "Streams every claim event to the analytics data lake ingester"
  event_bus_name = aws_cloudwatch_event_bus.claims_bus.name

  event_pattern = jsonencode({
    source = [
      "usaa.claims.mobile-app",
      "usaa.claims.processor",
      "usaa.claims.fraud-detector"
    ]
  })
}

resource "aws_cloudwatch_event_target" "all_events_to_analytics" {
  rule           = aws_cloudwatch_event_rule.all_claim_events.name
  event_bus_name = aws_cloudwatch_event_bus.claims_bus.name
  target_id      = "SendToAnalyticsIngester"
  arn            = aws_lambda_function.analytics_ingester.arn
}

# =============================================================================
# Lambda Permissions — Allow EventBridge to invoke each Lambda
# =============================================================================
resource "aws_lambda_permission" "allow_eb_claims_processor" {
  statement_id  = "AllowEventBridgeInvokeClaimsProcessor"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.claims_processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.claim_filed.arn
}

resource "aws_lambda_permission" "allow_eb_fraud_detector" {
  statement_id  = "AllowEventBridgeInvokeFraudDetector"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fraud_detector.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.claim_validated.arn
}

resource "aws_lambda_permission" "allow_eb_notification_sender" {
  statement_id  = "AllowEventBridgeInvokeNotificationSender"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notification_sender.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.claim_status_change.arn
}

resource "aws_lambda_permission" "allow_eb_analytics_ingester" {
  statement_id  = "AllowEventBridgeInvokeAnalyticsIngester"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.analytics_ingester.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.all_claim_events.arn
}
