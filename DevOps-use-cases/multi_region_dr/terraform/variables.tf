variable "primary_alb_dns_name" {
  type        = string
  description = "DNS name of the primary ALB in us-east-1"
  default     = "primary-alb-123456789.us-east-1.elb.amazonaws.com"
}

variable "primary_alb_zone_id" {
  type        = string
  description = "Zone ID of the primary ALB in us-east-1"
  default     = "Z35SXDOTRQ7X7K"
}

variable "dr_alb_dns_name" {
  type        = string
  description = "DNS name of the standby ALB in us-west-2"
  default     = "standby-alb-987654321.us-west-2.elb.amazonaws.com"
}

variable "dr_alb_zone_id" {
  type        = string
  description = "Zone ID of the standby ALB in us-west-2"
  default     = "Z1H1FL5HABSF5"
}
