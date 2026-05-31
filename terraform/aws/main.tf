terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "fin-enterprise-terraform-state"
    key            = "aws/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "fin-enterprise-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Client      = "fin-enterprise-application"
    }
  }
}

locals {
  name_prefix = "${var.project}-${var.environment}"
  azs         = slice(data.aws_availability_zones.available.names, 0, 2)
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source      = "../modules/aws-vpc"
  name_prefix = local.name_prefix
  cidr        = "10.${var.environment == "prod" ? 1 : 2}.0.0/16"
  azs         = local.azs
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "RDS PostgreSQL access from EKS nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "Private RFC1918 only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnets"
  subnet_ids = module.vpc.private_subnet_ids
}

resource "aws_db_instance" "postgres" {
  identifier                  = "${local.name_prefix}-assets-db"
  engine                      = "postgres"
  engine_version              = "16"
  instance_class              = var.db_instance_class
  allocated_storage           = 50
  max_allocated_storage       = 200
  storage_encrypted           = true
  db_name                     = "fin_enterprise_assets"
  username                    = "fin_enterprise_admin"
  manage_master_user_password = true
  vpc_security_group_ids      = [aws_security_group.rds.id]
  db_subnet_group_name        = aws_db_subnet_group.main.name
  backup_retention_period     = var.environment == "prod" ? 30 : 7
  deletion_protection         = var.environment == "prod"
  skip_final_snapshot         = var.environment != "prod"
  multi_az                    = var.environment == "prod"
  publicly_accessible         = false

  tags = { Name = "${local.name_prefix}-rds" }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${local.name_prefix}-eks"
  cluster_version = var.eks_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = length(var.authorized_api_cidrs) > 0 ? var.authorized_api_cidrs : ["0.0.0.0/0"]

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      min_size       = var.environment == "prod" ? 2 : 1
      max_size       = var.environment == "prod" ? 6 : 3
      desired_size   = var.environment == "prod" ? 3 : 2
      instance_types = ["t3.large"]
    }
  }

  cluster_enabled_log_types = ["api", "audit", "authenticator"]
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "rds_endpoint" {
  value     = aws_db_instance.postgres.endpoint
  sensitive = true
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
