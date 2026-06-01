# 1-Hour Demo — Script & Discussion Points

**Project:** Financial Enterprise Application (institutional asset management API + full DevOps platform)  
**Audience:** Hiring panel, platform/SRE interview, or technical stakeholders  
**Companion (deeper minute-by-minute):** [EKS_DEMO_SCRIPT.md](EKS_DEMO_SCRIPT.md)

---

## Before you start (~5 min)

| Check | Action |
|-------|--------|
| Docker | `docker compose ps` healthy (or `make docker-up`) |
| Tabs | Open files in [Files to have open](#files-to-have-open) |
| Optional | `make kind-up && make argocd-up` — Argo app **Synced / Healthy** |
| Optional | `terraform init -backend=false` in `terraform/aws` so `plan` is fast |

---

## Files to have open (tab order)

| # | Path | Why |
|---|------|-----|
| 1 | [ARCHITECTURE.md](ARCHITECTURE.md) | Business + hybrid cloud story |
| 2 | `app/main.py` | Lifespan, `/health` vs `/ready`, metrics |
| 3 | `.github/workflows/ci-cd.yml` | End-to-end delivery on `main` |
| 4 | `terraform/aws/main.tf` | VPC, EKS, RDS |
| 5 | `k8s/base/deployment.yaml` | Probes, securityContext, workload |
| 6 | `k8s/overlays/staging/kustomization.yaml` | Env promotion (Kustomize) |
| 7 | `checkov.yaml` | IaC policy gate |
| 8 | [KIND_ARGOCD.md](KIND_ARGOCD.md) or Argo CD UI | GitOps closer |

---

## Opening script (0:00–0:05)

**Say:**

> “I built an institutional **Financial Enterprise** stack: portfolios, holdings, and NAV-style reporting. The demo is how we take that API from **git to production-like controls**: automated CI/CD, container scanning, **GHCR** as the primary registry, **Kubernetes** on AWS (and a DR path on GCP), and **observability**. Locally I reproduce the same Kubernetes manifests on **Kind** and optional **Argo CD** so the story is believable without burning cloud budget.”

**Discussion points**

- Why asset management (relational data, audit posture, SLAs) vs a generic todo API.
- “Regulated-adjacent” habits: no public DB, encrypted state, gates before deploy.

---

## Application (0:05–0:12)

**Live (pick one)**

- Swagger: `http://localhost:8000/docs` → **POST** `/api/v1/portfolios` with a small JSON body.
- **GET** `http://localhost:8000/metrics` (Prometheus text).

**Say:**

> “FastAPI + async PostgreSQL. **`/health`** is process-up; **`/ready`** checks the database so Kubernetes does not send traffic until we can serve.”

**Discussion points**

- Separation of liveness vs readiness; impact on rollouts and DB outages.
- Alembic under `database/` for schema migrations (mention briefly).

---

## CI/CD & artifact (0:12–0:22)

**Say:**

> “On **pull requests**, `ci.yml` runs Python quality: Ruff, MyPy, Bandit, pytest with coverage. On **merge to `main`**, `ci-cd.yml` runs the full path: reusable Python CI, then **Docker build + Trivy + push to GHCR**. If Sonar is configured, **SonarQube** runs as a **deploy gate** before Kind or EKS deploy so a failed quality gate does not promote the image to cluster deploy jobs.”

**Walk the jobs (show `ci-cd.yml`)**

| Job / area | Talking point |
|------------|----------------|
| `python-ci` | Lint, types, tests, coverage — fail fast |
| `build-scan-push` | Trivy SARIF to GitHub Security; image to **GHCR**; optional Docker Hub mirror |
| `sonarqube-gate` | Optional SonarCloud; when enabled, blocks **deploy-kind** / **deploy-staging** on failure |
| `terraform-cloud-iac` | **Opt-in** (`TERRAFORM_CI_ENABLED=true`): fmt, Checkov, validate AWS + GCP |
| `deploy-kind` | Same `k8s/overlays/local` as laptop; proves CI image works in K8s |
| `deploy-staging` | **Opt-in** EKS (`EKS_STAGING_ENABLED` + OIDC); GitOps alternative: Argo CD |
| `deploy-prod-gcp-dr` | Manual `workflow_dispatch`; hybrid DR narrative |

**Discussion points**

- **GHCR + `GITHUB_TOKEN`**: no long-lived registry password for the default path.
- **OIDC** for AWS (`AWS_ROLE_ARN`) — no static AWS keys in GitHub.
- End-to-end story: [END_TO_END_GITHUB.md](END_TO_END_GITHUB.md).

---

## Terraform & AWS (0:22–0:38)

**Say:**

> “`terraform/aws` provisions VPC, private subnets for EKS and RDS, NAT for egress, the EKS control plane and node groups, and **RDS PostgreSQL** — not click-ops. State can live in S3 + DynamoDB lock (`terraform/aws/bootstrap/`).”

**Optional live (no cost if you only plan)**

```bash
cd terraform/aws
terraform init -backend=false
terraform validate
terraform plan -var="environment=staging" -input=false
```

**Discussion points**

| Topic | Point |
|-------|--------|
| Private subnets | Nodes and DB without public IPs |
| RDS | `storage_encrypted`, not publicly accessible; Multi-AZ in prod |
| EKS | Managed node groups, cluster logging, API access restrictions in real prod |
| Checkov | Misconfig fails CI before `apply` |
| Drift | Scheduled `terraform plan` + alerts in a real org |

---

## Kubernetes (0:38–0:50)

**Say:**

> “Manifests are **Kustomize**: a **base** plus **overlays** per environment. Same patterns locally on Kind and in EKS.”

**Show `k8s/base/deployment.yaml`**

| Field | Discussion |
|-------|--------------|
| `readinessProbe` `/ready` | Traffic only when DB-backed checks pass |
| `livenessProbe` `/health` | Restart stuck pods |
| `resources` | Requests for scheduling; limits for noisy neighbor |
| `runAsNonRoot` / `securityContext` | Baseline hardening |

**Also mention:** HPA, Ingress, staging overlay patches.

**Optional live — Kind**

```bash
curl -sf http://localhost:30080/health
kubectl get pods -n fin-enterprise-local
```

**Say:**

> “Argo CD can sync the same paths — see `argocd/applications/fin-enterprise-api-local.yaml` for GitOps.”

**Whiteboard one-liner**

`ALB → Ingress → Service → Pod → RDS`

---

## Observability & close (0:50–1:00)

**Say:**

> “Prometheus scrapes `/metrics`; Grafana dashboards and `observability/prometheus/alerts.yml` give SRE-style signals. **GCP** in `terraform/gcp/` is a **DR slice** — warm standby, not naive active-active across clouds.”

**Live (if compose stack up):** Grafana `http://localhost:3000` — mention RUNBOOK for rollback (`kubectl rollout undo`).

**Closing (memorize)**

> “**Terraform** defines secure networking and data plane; **CI/CD** builds and scans then publishes a **single immutable image** to **GHCR**; **Kubernetes** runs it with probes and autoscaling; **observability** and **GitOps** close the loop for operations.”

**Strong optional lines**

- “I can show rollback in under two minutes.”
- “Trivy + Checkov are shift-left gates before anything touches a cluster.”

---

## Demo modes (pick one)

| Mode | Best when |
|------|-----------|
| **A — Hybrid** | No AWS spend: Compose + Kind + `terraform plan` + Argo story |
| **B — Live EKS** | Cluster exists; `kubectl` against staging |
| **C — GitHub-only** | Screen-share Actions + pre-recorded `kubectl` clip |

---

## Likely Q&A (short answers)

| Question | Answer |
|----------|--------|
| Why EKS not EC2? | Rolling updates, HPA, portable K8s, IAM integration |
| Why RDS not Postgres in-cluster? | Backups, patching, Multi-AZ maturity for finance data |
| Where is the image? | **GHCR** (`ghcr.io/<owner>/financial-enterprise-asset-api:<sha>`) |
| Secrets in cluster? | K8s Secrets today; prod → External Secrets + cloud SM |
| Rollback? | `kubectl rollout undo` or git revert + Argo sync |
| Multi-cloud? | DR / regulatory; avoid split-brain — staged DR, not active-active day one |
| Cost? | Right-size nodes and RDS per env; autoscaling bounds |

---

## Related

- [EKS_DEMO_SCRIPT.md](EKS_DEMO_SCRIPT.md) — extended talk track + panel tips  
- [EKS_DEMO_CHECKLIST.md](EKS_DEMO_CHECKLIST.md) — prep checklist  
- [INTERVIEW_PREP.md](INTERVIEW_PREP.md) — Q&A depth  
- [RUNBOOK.md](RUNBOOK.md) — operations  
