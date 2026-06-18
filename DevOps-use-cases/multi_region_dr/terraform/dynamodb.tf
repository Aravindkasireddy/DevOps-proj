# DynamoDB Global Tables replication for Multi-Region Data Parity

resource "aws_dynamodb_table" "usaa_banking" {
  name             = "usaa-banking-core"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "AccountID"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "AccountID"
    type = "S"
  }

  replica {
    region_name = "us-west-2"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Environment    = "Production"
    Project        = "DR-Resiliency"
    SecurityPolicy = "PCI-DSS-Enforced"
  }
}
