variable "aws_region" {
  type        = string
  description = "AWS region for all resources"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, production)"
  default     = "production"
}

variable "project_name" {
  type        = string
  description = "Project identifier used for resource naming"
  default     = "usaa-claims"
}

variable "teams_webhook_url" {
  type        = string
  description = "Microsoft Teams incoming webhook URL for claims operations alerts"
  sensitive   = true
  default     = "https://usaa.webhook.office.com/webhookb2/mock-claims-ops-webhook"
}

variable "member_notification_email" {
  type        = string
  description = "Default email for SNS subscription testing"
  default     = "claims-ops@usaa.com"
}
