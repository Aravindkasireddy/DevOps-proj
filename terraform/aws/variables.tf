variable "environment" {
  description = "dev | staging | prod"
  type        = string
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "fin-enterprise"
}

variable "eks_version" {
  type    = string
  default = "1.31"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.medium"
}

variable "authorized_api_cidrs" {
  description = "CIDRs allowed to reach EKS public API"
  type        = list(string)
  default     = []
}
