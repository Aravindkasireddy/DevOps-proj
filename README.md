# Financial Enterprise Application — Enterprise DevOps Platform

Production-style reference project for **Financial Enterprise Application**: a portfolio & holdings platform with full DevOps toolchain coverage (CI/CD, IaC, hybrid cloud, security, K8s/VM deploy, observability).

> **Use case**: Institutional asset management — portfolios, holdings, NAV, and compliance-ready audit trails.

## Architecture (high level)

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────────────────────────┐
│  Developers │────▶│ GitHub (SCM) │────▶│ GitHub Actions (CI/CD)              │
└─────────────┘     └──────────────┘     │ lint · test · SAST · build · scan   │
                                         └──────────┬──────────────────────────┘
                                                    │
                    ┌───────────────────────────────┼───────────────────────────────┐
                    ▼                               ▼                               ▼
            ┌───────────────┐              ┌────────────────┐              ┌─────────────────┐
            │ GHCR          │              │ JFrog          │              │ Checkov (IaC)   │
            │ (+ opt. Hub)  │              │ Artifactory    │              │ Terraform scan  │
            └───────┬───────┘              └────────┬───────┘              └────────┬────────┘
                    │                               │                               │
                    └───────────────────────────────┼───────────────────────────────┘
                                                    ▼
                              ┌─────────────────────────────────────────┐
                              │ Terraform (Hybrid Cloud)                │
                              │  AWS: VPC, EKS, RDS  │  GCP: GKE, Cloud SQL│
                              └─────────────────────────────────────────┘
                                                    │
                    ┌───────────────────────────────┴───────────────────────────────┐
                    ▼                                                               ▼
            ┌───────────────┐                                              ┌───────────────┐
            │ Kubernetes    │                                              │ VM (systemd)  │
            │ (EKS + GKE)   │                                              │ Ansible       │
            └───────┬───────┘                                              └───────┬───────┘
                    │                                                               │
                    └───────────────────────────────┬───────────────────────────────┘
                                                    ▼
                              ┌─────────────────────────────────────────┐
                              │ Observability: Prometheus · Grafana ·   │
                              │ structured logs · health/metrics        │
                              └─────────────────────────────────────────┘
```

## Quick start (local)

**Docker Compose** (fastest — API + DB + Grafana):

```bash
cp .env.example .env
make docker-up
open http://localhost:8000/docs    # API
open http://localhost:3000         # Grafana
```

**Kind + Argo CD** (Kubernetes + GitOps — interview gold):

On **`main`**, [CI/CD](.github/workflows/ci-cd.yml) also runs **Deploy to Kind (CI)** on GitHub-hosted runners (same `k8s/overlays/local` as below). EKS staging is opt-in via repo variable `EKS_STAGING_ENABLED` — see [docs/END_TO_END_GITHUB.md](docs/END_TO_END_GITHUB.md).

```bash
export ARGOCD_REPO_URL=https://github.com/Aravindkasireddy/DevOps-proj.git
make kind-up          # cluster + load image
make argocd-up        # Argo CD + sync from git
# OR before git push:  make kind-apply
curl http://localhost:30080/health
```

See **[docs/KIND_ARGOCD.md](docs/KIND_ARGOCD.md)** for the full walkthrough.

## Repository layout

| Path | Purpose |
|------|---------|
| `app/` | FastAPI asset management API |
| `database/` | SQL schema + Alembic migrations |
| `docker/` | Dockerfile, compose overrides |
| `.github/workflows/` | CI/CD pipelines |
| `terraform/aws`, `terraform/gcp` | Hybrid cloud IaC |
| `k8s/` | Kubernetes manifests (EKS/GKE/Kind) |
| `kind/` | Kind cluster config |
| `argocd/` | Argo CD AppProject & Applications (GitOps) |
| `ansible/` | VM deployment playbook |
| `observability/` | Prometheus, Grafana, alerts |
| `docs/` | Architecture, runbook, **interview prep** |

## DevOps toolchain map

| Tool | Where | Interview topic |
|------|-------|-----------------|
| **Ruff / MyPy** | `app/`, CI | Linting, static typing |
| **pytest + coverage** | `app/tests/` | Unit testing, quality gates |
| **Bandit** | CI | Python SAST |
| **SonarQube Cloud** | `sonarqube.yml` (optional) | Centralized quality + coverage; needs `SONAR_*` setup |
| **Trivy** | CI | Container image scanning |
| **Checkov** | CI + `terraform/` | IaC security (CIS, misconfig) |
| **GitHub Actions** | `.github/workflows/` | SCM hooks, pipelines, environments |
| **Terraform** | `terraform/` | IaC, modules, state, workspaces |
| **AWS + GCP** | `terraform/aws`, `terraform/gcp` | Hybrid cloud, DR, multi-region |
| **GHCR** | `ci-cd.yml` | Primary registry (`GITHUB_TOKEN`); optional Docker Hub mirror |
| **Artifactory** | `ci-cd.yml`, `docker/artifactory.md` | Optional enterprise mirror / GKE override |
| **Kind** | `kind/`, `make kind-up` | Local Kubernetes |
| **Argo CD** | `argocd/` | GitOps, app-of-apps, drift sync |
| **EKS / GKE** | `k8s/` | Orchestration, HPA, ingress |
| **Ansible** | `ansible/` | VM immutable-ish deploy |
| **Prometheus / Grafana** | `observability/` | SLIs, dashboards, alerting |

## Environments

| Env | AWS | GCP | Notes |
|-----|-----|-----|-------|
| `dev` | Single AZ, small nodes | Optional GKE dev | Fast iteration |
| `staging` | EKS + RDS replica | GKE for DR drill | Pre-prod validation |
| `prod` | EKS primary (us-east-1) | GKE secondary (us-central1) | Hybrid active-passive |

Configure via Terraform workspaces — see `docs/ARCHITECTURE.md`.

## Prerequisites

- Docker Desktop 4.x+
- Python 3.12+ (local dev without Docker)
- Terraform 1.7+
- `checkov`, `trivy` (or use CI only)
- AWS/GCP accounts for real deploy (optional for learning)

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Runbook](docs/RUNBOOK.md)
- [Interview prep (mapped to this repo)](docs/INTERVIEW_PREP.md)
- [**EKS demo script (1 hour)**](docs/EKS_DEMO_SCRIPT.md) — presentation speaker notes
- [**EKS demo checklist**](docs/EKS_DEMO_CHECKLIST.md) — prep before presenting
- [Kind + Argo CD lab](docs/KIND_ARGOCD.md)
- [**Reusable GitHub Actions**](docs/CICD_REUSABLE.md) — `workflow_call` Python + Docker workflows
- [**End-to-end GitHub (GHCR)**](docs/END_TO_END_GITHUB.md) — permissions, secrets, private pull guidance
- [**SonarQube / SonarCloud**](docs/SONARQUBE.md) — optional code quality + coverage in Actions

## Client context

**Financial Enterprise Application** — fixed income & structured credit focus. This demo models:

- **Portfolios** — fund sleeves, strategy tags
- **Holdings** — positions with CUSIP/ISIN, quantity, cost basis
- **NAV snapshots** — daily valuation for reporting

---

Built as a **senior DevOps engineer portfolio project**: every folder answers real interview questions with runnable config, not slide-deck theory.
