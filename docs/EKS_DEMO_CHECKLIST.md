# EKS Demo — Preparation Checklist

Use this **1–2 days before** your presentation. Tick each box.

---

## Knowledge prep (must explain without reading)

- [ ] Draw: Internet → ALB/Ingress → Service → Pod → RDS  
- [ ] Explain difference: `/health` vs `/ready`  
- [ ] Explain: Terraform state (S3) + lock (DynamoDB)  
- [ ] Explain: Why private subnets for EKS + RDS  
- [ ] Explain: CI job order in `ci-cd.yml`  
- [ ] Explain: Trivy vs Checkov (image vs IaC)  
- [ ] Explain: Rollback command or GitOps revert  
- [ ] One weakness + improvement (e.g. “prod would use External Secrets Operator”)

---

## Local environment (Hybrid demo — Mode A)

```bash
cd /Users/aravind/Desktop/Devops/DevOps-proj
cp .env.example .env   # if not done
make docker-up
curl -sf http://localhost:8000/health
curl -sf -o /dev/null -w "%{http_code}" http://localhost:8000/docs   # expect 200
```

- [ ] API docs load  
- [ ] Create one portfolio in Swagger  
- [ ] Grafana login works (http://localhost:3000)  
- [ ] Prometheus shows `fin-enterprise-api` target UP (http://localhost:9090/targets)

### Kind (optional 5-min segment)

```bash
make kind-up      # ~2 min first time
make kind-apply
curl http://localhost:30080/health
kubectl get pods -n fin-enterprise-local
```

- [ ] Kind cluster creates  
- [ ] API responds on NodePort 30080  

### Terraform plan (no apply)

```bash
brew install terraform checkov   # if missing
cd terraform/aws
terraform init -backend=false
terraform validate
checkov -d ../.. --config-file ../../checkov.yaml
terraform plan -var="environment=staging" -input=false
```

- [ ] Plan output shows EKS + RDS + VPC (or explain backend not bootstrapped yet)

---

## AWS live demo (Mode B — optional)

### Prerequisites

- [ ] AWS account with admin or scoped IAM  
- [ ] `aws` CLI configured  
- [ ] S3 bucket + DynamoDB table for state (one-time bootstrap)

### One-time bootstrap

```bash
cd terraform/aws/bootstrap
terraform init
terraform apply
# Creates: fin-enterprise-terraform-state (S3), fin-enterprise-terraform-locks (DynamoDB)
```

### Staging apply

```bash
cd ../   # terraform/aws
terraform init
terraform workspace select staging || terraform workspace new staging
terraform plan -var="environment=staging"
terraform apply -var="environment=staging"   # $$ cost — confirm before demo
```

- [ ] `terraform output eks_cluster_name`  
- [ ] `aws eks update-kubeconfig --name fin-enterprise-staging-eks --region us-east-1`  
- [ ] `kubectl get nodes`

### Deploy app to EKS

```bash
# After CI has pushed an image, or set image manually:
kubectl apply -k k8s/overlays/staging
kubectl rollout status deployment/fin-enterprise-api -n fin-enterprise-staging
```

- [ ] Pods Running  
- [ ] Ingress / port-forward tested  

### Teardown after practice (save cost)

```bash
terraform destroy -var="environment=staging"
```

---

## GitHub / CI prep

- [ ] Repo pushed to GitHub  
- [ ] Secrets documented (not shown on screen): `DOCKERHUB_*`, `AWS_ROLE_ARN`  
- [ ] One successful `CI/CD` workflow run on `main` to show in UI  
- [ ] Security tab: Trivy SARIF upload (if enabled)

---

## Presentation materials

- [ ] `docs/EKS_DEMO_SCRIPT.md` printed or on second monitor  
- [ ] Architecture diagram (from script or `ARCHITECTURE.md`)  
- [ ] Sample JSON for portfolio POST (in script)  
- [ ] Backup: screenshots if live demo fails  

---

## Day-of timeline

| Time | Task |
|------|------|
| T-30 min | Start Docker, `make docker-up` |
| T-15 min | Open browser tabs (docs, Grafana, Prometheus, GitHub Actions) |
| T-10 min | Open IDE files from script |
| T-5 min | Test `/docs` once more |
| T-0 | Start recording / present |

---

## Port reference (your Mac)

| Service | URL | Compose project |
|---------|-----|-----------------|
| API | http://localhost:8000/docs | devops-proj |
| Grafana | http://localhost:3000 | devops-proj |
| Prometheus | http://localhost:9090 | devops-proj |
| Kind API | http://localhost:30080/health | kind |

If ports conflict, stop other Docker stacks (`enterprise-api`, old monitoring) first.

---

## If something breaks during demo

| Symptom | Quick fix |
|---------|-----------|
| `/docs` 500 | `docker compose up -d --build api` |
| Port in use | `docker ps` → stop conflicting container |
| Kind ImagePullBackOff | `kind load docker-image financial-enterprise/asset-api:local --name fin-enterprise` |
| Terraform backend error | Use `terraform init -backend=false` for plan-only demo |
| Grafana plain “Internal Server Error” | Hard refresh; use http://localhost:3000/login |
