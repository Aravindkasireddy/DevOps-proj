# DevOps Interview Prep — Mapped to This Repository

Study each topic, then **open the linked path** and explain it aloud as if in a senior DevOps loop.

---

## 1. Application & Developer workflow

| Question | Answer in this repo |
|----------|---------------------|
| How do you structure a production API? | FastAPI layers: `app/main.py`, routers, SQLAlchemy models, Pydantic schemas |
| How do devs run locally? | `make docker-up`, OpenAPI at `/docs` |
| How do you handle config/secrets? | `app/config.py` + env vars; never commit `.env` |

**Demo**: Create portfolio → add holding → record NAV → call `/summary`.

---

## 2. Code quality, lint, SAST, unit tests

| Question | Where |
|----------|-------|
| Linting? | Ruff — `pyproject.toml`, CI `ci.yml` |
| Type safety? | MyPy strict mode |
| SAST? | Bandit — `sast` job, `make sast` |
| Unit tests & coverage gate? | `app/tests/`, pytest, 70% fail_under |
| Pre-commit? | `.pre-commit-config.yaml` |

**Senior tip**: Separate **fast PR checks** (`ci.yml`) from **heavy CD** (`ci-cd.yml`) — interviewers love talking about feedback time vs completeness.

---

## 3. GitHub — SCM & pipelines

| Question | Where |
|----------|-------|
| Branch strategy? | `main` (prod path), `develop` (integration), feature branches |
| PR gates? | `ci.yml` on pull_request |
| Environments & approvals? | `environment: staging/production` in `ci-cd.yml` |
| OIDC to cloud? | `AWS_ROLE_ARN`, GCP Workload Identity in CD workflow |
| Caching? | Docker GHA cache in build steps |
| Reusable workflows? | `reusable-python-ci.yml`, `reusable-docker-*.yml` — [docs/CICD_REUSABLE.md](CICD_REUSABLE.md) |

**Talking point**: `concurrency` groups cancel stale PR builds — saves runner minutes.

---

## 4. Docker & registries

| Question | Where |
|----------|-------|
| Multi-stage Dockerfile? | `docker/Dockerfile` — builder + non-root runtime |
| Local compose? | `docker-compose.yml` |
| GHCR / registries? | `ci-cd.yml` → `reusable-docker-release.yml` pushes `ghcr.io/<owner>/financial-enterprise-asset-api`; optional Docker Hub / Artifactory |
| Artifactory? | `docker/artifactory.md`, dual registry in metadata-action |
| Image scanning? | Trivy action, fail on Critical |

**Interview**: Explain **image promotion** dev → staging → prod, not retagging `latest` in prod blindly.

---

## 5. Terraform & IaC

| Question | Where |
|----------|-------|
| State backend? | S3 + DynamoDB (`terraform/aws/bootstrap/`), GCS for GCP |
| Modules? | `terraform/modules/aws-vpc`, EKS module |
| Workspaces / envs? | `var.environment` — dev/staging/prod |
| Hybrid cloud? | `terraform/aws` (primary), `terraform/gcp` (DR) |
| `terraform plan` in CI? | `ci-cd.yml`, `terraform-apply.yml` |
| Drift detection? | Scheduled plan workflow (extend) |

**Deep dive**: Why `manage_master_user_password` on RDS? Secrets Manager integration, no password in TF state plaintext.

---

## 6. Checkov / IaC security

| Question | Where |
|----------|-------|
| When do you scan IaC? | PR plan job + manual apply workflow |
| What fails the build? | `checkov-action` soft_fail: false |
| Suppressions? | `checkov.yaml` with documented skip |

**Sample questions**:

- *S3 public bucket?* — bootstrap uses `public_access_block`
- *RDS encrypted?* — `storage_encrypted = true`
- *EKS logging?* — `cluster_enabled_log_types`

---

## 7. AWS & GCP hybrid

| Question | AWS | GCP |
|----------|-----|-----|
| Compute | EKS | GKE private nodes |
| Database | RDS Postgres | Cloud SQL |
| Networking | VPC module, private subnets | VPC + private subnet |
| Deploy | `deploy-staging` job | `deploy-prod-gcp-dr` |

**Why hybrid?** Regulatory DR, vendor diversification, acquisition integration — not because multi-cloud is always simpler.

---

## 8. Kubernetes vs VM

| Topic | K8s | VM |
|-------|-----|-----|
| Path | `k8s/base`, overlays | `ansible/playbooks/deploy-vm.yml` |
| Scaling | HPA | manual / ASG (extend) |
| Health | readiness/liveness | compose healthcheck |
| Metrics | ServiceMonitor | Prometheus scrape static target |
| Secrets | K8s Secret (replace with ESO) | env in compose template |

**When VMs?** Licensed software, legacy monolith, hard NUMA requirements — still common in finance.

---

## 8b. Kind (local Kubernetes)

| Question | Where |
|----------|-------|
| Why Kind vs minikube? | `kind/kind-config.yaml` — multi-node, CI-friendly, uses containerd |
| Load local images? | `kind load docker-image` in `scripts/kind-up.sh` |
| Local overlay? | `k8s/overlays/local` — in-cluster Postgres, NodePort 30080 |
| Test without cloud? | `make kind-apply` before EKS costs money |

**Demo**: `make kind-up && make kind-apply && curl localhost:30080/health`

---

## 8c. Argo CD (GitOps)

| Question | Where |
|----------|-------|
| What is GitOps? | Cluster state = git; Argo reconciles drift |
| App-of-Apps? | `argocd/bootstrap/root-app.yaml` → `argocd/applications/*` |
| Projects / RBAC? | `argocd/projects/fin-enterprise-project.yaml` |
| Local vs staging app? | `fin-enterprise-api-local.yaml` vs `fin-enterprise-api-staging.yaml` |
| Image not in git? | `ignoreDifferences` on Deployment image (Kind workflow) |
| Rollback? | `argocd app rollback` or revert git commit |

**vs `kubectl apply` in CI**: Push-based CD updates cluster directly; GitOps pulls from git — better audit trail and self-heal.

Full guide: `docs/KIND_ARGOCD.md`

---

## 9. Observability

| Question | Where |
|----------|-------|
| RED metrics? | `http_requests_total`, `http_request_duration_seconds` |
| Dashboards? | `observability/grafana/dashboards/fin-enterprise-api.json` |
| Alerting? | `observability/prometheus/alerts.yml` |
| Structured logs? | `app/logging_config.py` JSON to stdout |

**SRE answer**: SLI = availability + latency; SLO example: 99.9% `/ready` success over 30d; error budget drives release cadence.

---

## 10. Database

| Question | Where |
|----------|-------|
| Schema versioning? | Alembic `database/migrations/` |
| ORM? | SQLAlchemy 2.0 async |
| Prod DB? | RDS / Cloud SQL in Terraform |
| Backup / PITR? | `backup_retention_period`, Cloud SQL PITR flag |
| Connection from K8s? | Secret `DATABASE_URL` |

---

## 11. Classic scenario questions (practice aloud)

1. **Blue/green vs rolling**: Rolling via kubectl or Argo CD sync; blue/green → Argo Rollouts or dual Service + switch.

2. **GitOps sync failed**: `argocd app get fin-enterprise-api-local`; check repo URL, image loaded on Kind nodes, postgres ready.

3. **Secrets leak in git**: Rotate creds, `git filter-repo`, enable secret scanning, use External Secrets.

4. **Terraform state lock stuck**: DynamoDB lock item, `force-unlock` after verifying no active apply.

5. **Pod CrashLoopBackOff**: `kubectl logs --previous`, check `/ready` DB URL, image pull secrets for Artifactory.

6. **High latency**: Grafana P95 panel → slow queries → RDS Performance Insights → index on `holdings.portfolio_id`.

7. **Disaster recovery**: Fail DNS to GCP ingress; promote Cloud SQL replica; RTO/RPO defined with business.

8. **Zero-downtime DB migration**: Expand-contract pattern; backward-compatible Alembic revisions.

9. **Supply chain security**: Trivy + Checkov + signed images (Cosign — extension exercise).

---

## 12. 30-second elevator pitch

> "I built an institutional asset management API for the Financial Enterprise Application with full CI/CD on GitHub Actions — lint, Bandit, tests, Trivy, and Checkov gates. Images publish to **GHCR** by default, with optional Docker Hub and Artifactory mirrors for enterprise promotion. Terraform provisions hybrid AWS EKS+RDS and GCP GKE+Cloud SQL for DR. Locally I use Kind and Argo CD GitOps; in cloud we deploy Kustomize overlays to EKS/GKE or Ansible to VMs, with Prometheus/Grafana observability and PostgreSQL migrations via Alembic."

---

## Suggested learning order (2 weeks)

| Day | Focus |
|-----|-------|
| 1-2 | Run app locally, read API code, write a test |
| 3-4 | Trace `ci.yml` and break a build intentionally |
| 5-6 | Read Terraform AWS module, run `checkov` |
| 7-8 | `make kind-up` + `make kind-apply`, then `make argocd-up` after git push |
| 9 | Ansible VM playbook (Vagrant optional) |
| 10 | Grafana dashboards + trigger test alert |
| 11-12 | Mock interviews using sections 1–11 + Kind/Argo CD |
