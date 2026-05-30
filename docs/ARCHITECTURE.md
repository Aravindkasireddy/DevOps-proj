# Architecture — Financial Enterprise Application Platform

## Business context

**Financial Enterprise Application** manages fixed income and structured credit portfolios. This platform models:

| Domain entity | Purpose |
|---------------|---------|
| Portfolio | Fund sleeve (strategy, base currency) |
| Holding | Position (symbol, CUSIP, quantity, cost basis) |
| NAV snapshot | End-of-day valuation for investor reporting |

## Why Asset Management (not generic CRUD)?

Interviewers expect domain awareness. Asset management maps cleanly to:

- **Relational data** (PostgreSQL, migrations, backups)
- **Compliance** (audit trails, encryption, access control)
- **Hybrid cloud** (primary trading/reporting region + DR)
- **Observability** (latency SLAs on pricing/NAV APIs)

Alternatives considered: e-commerce (less relevant for institutional finance), generic todo app (too shallow for DevOps depth).

## Hybrid cloud design

```
                    ┌─────────────────────────────────────┐
                    │           Route 53 / Global LB       │
                    └─────────────────┬───────────────────┘
                                      │
              ┌───────────────────────┴───────────────────────┐
              ▼ ACTIVE (AWS us-east-1)                        ▼ DR (GCP us-central1)
    ┌─────────────────────┐                         ┌─────────────────────┐
    │ EKS (staging/prod)  │                         │ GKE (prod DR)       │
    │ fin-enterprise-api pods    │                         │ warm standby pods   │
    └──────────┬──────────┘                         └──────────┬──────────┘
               │                                                 │
    ┌──────────▼──────────┐                         ┌───────────▼──────────┐
    │ RDS PostgreSQL 16   │◀── logical replication ─│ Cloud SQL Postgres   │
    │ (primary writes)    │    (optional, prod)     │ (read replica / DR)  │
    └─────────────────────┘                         └──────────────────────┘
```

**Rationale (5+ yr engineer answer):**

- AWS: mature EKS + RDS, common for US asset managers
- GCP: secondary region for DR drills, BigQuery adjacency for analytics
- Not active-active across clouds initially — reduces split-brain and data consistency risk

## CI/CD pipeline stages

| Stage | Tool | Gate |
|-------|------|------|
| Commit | pre-commit | Local fast feedback |
| PR | GitHub Actions `ci.yml` | Lint, MyPy, Bandit, pytest ≥70% cov |
| Merge main | `ci-cd.yml` | Build, Trivy (no Critical), push registries |
| IaC | Checkov + `terraform plan` | No HIGH misconfigs |
| Deploy staging | kubectl + Kustomize | Rollout health |
| Deploy prod DR | Manual `workflow_dispatch` | Environment protection rules |

## Registry strategy

| Registry | When | Why |
|----------|------|-----|
| GHCR | Default on merge to `main` | Same vendor as CI; `GITHUB_TOKEN`; no extra registry secret |
| Docker Hub | Optional mirror | Familiar public path when secrets are configured |
| Artifactory | Optional staging/prod | RBAC, Xray, promotion; GKE DR can pull from here if `ARTIFACTORY_URL` is set |

## Deployment targets

| Target | Path | Use case |
|--------|------|----------|
| **Kind (local)** | `kind/`, `k8s/overlays/local` | Laptop K8s lab |
| **Argo CD (GitOps)** | `argocd/` | Declarative sync from git — app-of-apps |
| **Kubernetes** | `k8s/` | Primary — HPA, ingress, ServiceMonitor |
| **VM** | `ansible/` | Legacy workloads, lift-and-shift, compliance islands |

## Observability pillars

| Pillar | Implementation |
|--------|----------------|
| Metrics | Prometheus `/metrics`, RED dashboards in Grafana |
| Logs | JSON structured logs to stdout → cluster log agent |
| Traces | OTLP endpoint stub in `.env.example` (extend with Tempo/Jaeger) |
| Alerts | `observability/prometheus/alerts.yml` |

## Security controls

- **SAST**: Bandit on application code
- **Container**: Trivy in CD pipeline
- **IaC**: Checkov on Terraform (encryption, public access, logging)
- **Runtime**: K8s non-root, resource limits, NetworkPolicies (extend in prod)
- **Secrets**: External Secrets / Sealed Secrets (placeholder K8s secret)

## Database

- **Engine**: PostgreSQL 16
- **Migrations**: Alembic (`database/migrations/`)
- **Prod**: RDS (AWS) with encryption, backups, Multi-AZ in prod
- **DR**: Cloud SQL on GCP with PITR enabled in prod
