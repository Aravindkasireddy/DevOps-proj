# =============================================================================
# Step Functions — Multi-step claim approval orchestration workflow
# =============================================================================

resource "aws_iam_role" "step_function_exec" {
  name = "${var.project_name}-sfn-exec-role"

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

resource "aws_iam_policy" "step_function_permissions" {
  name = "${var.project_name}-sfn-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.claims_processor.arn,
          aws_lambda_function.fraud_detector.arn,
          aws_lambda_function.notification_sender.arn,
          aws_lambda_function.analytics_ingester.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "events:PutEvents"
        ]
        Resource = aws_cloudwatch_event_bus.claims_bus.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sfn_policy" {
  role       = aws_iam_role.step_function_exec.name
  policy_arn = aws_iam_policy.step_function_permissions.arn
}

resource "aws_sfn_state_machine" "claim_approval_workflow" {
  name     = "${var.project_name}-approval-workflow"
  role_arn = aws_iam_role.step_function_exec.arn

  definition = jsonencode({
    Comment = "USAA Insurance Claim Approval Workflow — Validates, scores for fraud, assigns adjuster, and notifies the member."
    StartAt = "ValidateClaim"

    States = {
      ValidateClaim = {
        Type     = "Task"
        Resource = aws_lambda_function.claims_processor.arn
        Comment  = "Step 1: Validate claim data completeness and write to DynamoDB"
        Next     = "FraudCheck"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyFailure"
          ResultPath  = "$.error"
        }]
      }

      FraudCheck = {
        Type     = "Task"
        Resource = aws_lambda_function.fraud_detector.arn
        Comment  = "Step 2: Run rule-based checks and ML fraud scoring"
        Next     = "EvaluateFraudScore"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyFailure"
          ResultPath  = "$.error"
        }]
      }

      EvaluateFraudScore = {
        Type    = "Choice"
        Comment = "Step 3: Route based on fraud risk score"
        Choices = [
          {
            Variable           = "$.fraudScore"
            NumericGreaterThan = 0.7
            Next               = "EscalateToSIU"
          },
          {
            Variable           = "$.fraudScore"
            NumericGreaterThan = 0.3
            Next               = "FlagForManualReview"
          }
        ]
        Default = "AutoApproveClaim"
      }

      AutoApproveClaim = {
        Type     = "Task"
        Resource = aws_lambda_function.notification_sender.arn
        Comment  = "Low risk — auto-approve and notify member"
        Parameters = {
          "claimId.$"  = "$.claimId"
          "memberId.$" = "$.memberId"
          "status"     = "APPROVED"
          "message"    = "Your claim has been approved. An adjuster will contact you within 24 hours."
        }
        Next = "RecordAnalytics"
      }

      FlagForManualReview = {
        Type     = "Task"
        Resource = aws_lambda_function.notification_sender.arn
        Comment  = "Medium risk — flag for human adjuster review"
        Parameters = {
          "claimId.$"  = "$.claimId"
          "memberId.$" = "$.memberId"
          "status"     = "PENDING_REVIEW"
          "message"    = "Your claim is under review. A claims specialist will reach out within 48 hours."
        }
        Next = "RecordAnalytics"
      }

      EscalateToSIU = {
        Type     = "Task"
        Resource = aws_lambda_function.notification_sender.arn
        Comment  = "High risk — escalate to Special Investigations Unit"
        Parameters = {
          "claimId.$"  = "$.claimId"
          "memberId.$" = "$.memberId"
          "status"     = "FRAUD_FLAGGED"
          "message"    = "Your claim is being reviewed by our specialized team. We will contact you shortly."
        }
        Next = "RecordAnalytics"
      }

      RecordAnalytics = {
        Type     = "Task"
        Resource = aws_lambda_function.analytics_ingester.arn
        Comment  = "Final step — stream the outcome to the data lake"
        End      = true
      }

      NotifyFailure = {
        Type     = "Task"
        Resource = aws_lambda_function.notification_sender.arn
        Comment  = "Error handler — notify operations team of pipeline failure"
        Parameters = {
          "claimId.$"  = "$.claimId"
          "memberId.$" = "$.memberId"
          "status"     = "PROCESSING_ERROR"
          "message"    = "An error occurred processing your claim. Our team has been notified and will follow up."
        }
        End = true
      }
    }
  })

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "Orchestrates the end-to-end claim approval workflow"
  }
}
