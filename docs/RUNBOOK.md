# Runbook — Financial Enterprise API

## Local development

```bash
make install
make test
make docker-up
curl http://localhost:8000/health
```

## Rollback (Kubernetes)

```bash
kubectl rollout undo deployment/fin-enterprise-api -n fin-enterprise-staging
kubectl rollout status deployment/fin-enterprise-api -n fin-enterprise-staging
```

## Rollback (VM / Ansible)

```bash
# Set previous image tag in inventory group_vars
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/deploy-vm.yml
```

## Database migration

```bash
export DATABASE_URL=postgresql+asyncpg://...
alembic -c database/alembic.ini upgrade head
```

## Incident: API down

1. Check `/health` and `/ready` — DB connectivity in `/ready`
2. Grafana → Financial Enterprise API dashboard → error rate & latency
3. `kubectl logs -l app=fin-enterprise-api -n fin-enterprise-staging --tail=200`
4. RDS: AWS Console → Performance Insights

## Incident: failed deployment

1. `kubectl describe pod -l app=fin-enterprise-api -n fin-enterprise-staging`
2. Verify image exists in the configured registry (typically GHCR)
3. Check Trivy SARIF in GitHub Security tab for blocked CVEs

## Terraform drift

```bash
cd terraform/aws && terraform plan -var="environment=staging"
```

## Checkov failure in CI

1. Read Checkov output in Actions log
2. Fix resource config or document suppression in `checkov.yaml` with ticket ID

## Secret rotation

1. Rotate RDS master password via AWS Secrets Manager
2. Update K8s secret or ExternalSecret
3. Rolling restart: `kubectl rollout restart deployment/fin-enterprise-api`
