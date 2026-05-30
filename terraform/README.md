# Hybrid Cloud Terraform

| Stack | Primary role | Region |
|-------|--------------|--------|
| **AWS** | Production API on EKS, RDS PostgreSQL | us-east-1 |
| **GCP** | DR / analytics GKE, Cloud SQL replica | us-central1 |

## Bootstrap state (one-time)

```bash
# AWS
cd terraform/aws/bootstrap && terraform init && terraform apply

# GCP
cd terraform/gcp/bootstrap && terraform init && terraform apply
```

## Deploy environment

```bash
cd terraform/aws
terraform workspace select staging || terraform workspace new staging
terraform plan -var="environment=staging"
terraform apply -var="environment=staging"
```

## Security scanning

```bash
checkov -d terraform/ --framework terraform
```

See `checkov.yaml` for suppressions with justification comments.
