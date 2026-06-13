# =============================================================================
# DynamoDB — Claims data store with status tracking
# =============================================================================

resource "aws_dynamodb_table" "claims_store" {
  name         = "${var.project_name}-store"
  billing_mode = "PAY_PER_REQUEST" # On-demand — auto-scales with claim volume
  hash_key     = "claimId"
  range_key    = "memberId"

  attribute {
    name = "claimId"
    type = "S"
  }

  attribute {
    name = "memberId"
    type = "S"
  }

  attribute {
    name = "claimStatus"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  # GSI: Query all claims by status (e.g., "PENDING_REVIEW", "APPROVED", "FRAUD_FLAGGED")
  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "claimStatus"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  # GSI: Query all claims by member (e.g., for member history lookups)
  global_secondary_index {
    name            = "MemberIndex"
    hash_key        = "memberId"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true # Required for financial compliance — audit trail
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "Insurance claims persistent store with status tracking"
  }
}
