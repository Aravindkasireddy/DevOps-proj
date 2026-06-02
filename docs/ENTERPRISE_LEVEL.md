# Operating this project at enterprise level

This doc turns “enterprise” into **concrete controls** you can turn on in **GitHub** and optional **repo splits**. The application code today is a **single monorepo**; nothing here replaces your org’s SOC2/HIPAA program—it maps common expectations to **actions**.

---

## 1. Source control and governance (Stage 1)

| Control | Where to set | Notes for this repo |
|--------|----------------|---------------------|
| **Branch protection on `main`** | GitHub → *Settings* → *Branches* → Branch protection rule | Require PR before merge; **do not allow bypass** for admins if policy requires. |
| **Required status checks** | Same rule → *Require status checks to pass* | Add checks from **`ci.yml`** (and **`ci-cd.yml`** if you require them before merge). Wait until workflows have run once so GitHub lists the check names. |
| **Require linear history** or **squash** | Branch rule | Pick what your org mandates. |
| **CODEOWNERS** | Repo root file **`CODEOWNERS`** (see template below) | Auto-request reviewers by path (`k8s/`, `terraform/`, `.github/workflows/`). |
| **Repository / org rulesets** | *Settings* → *Rules* → *Rulesets* | Stronger than classic branch rules; use for “every `main` commit must pass X”. |
| **Secret scanning + push protection** | *Settings* → *Code security and analysis* | Turn on if available on your plan; blocks accidental secret pushes. |

**`CODEOWNERS` template** (save as `CODEOWNERS` in the repo root; replace handles with your org):

```gitattributes
# Default owner for everything
* @YOUR_ORG/platform-team

# High-risk paths — require platform / security review
/.github/workflows/ @YOUR_ORG/platform-team
/k8s/ @YOUR_ORG/platform-team
/terraform/ @YOUR_ORG/platform-team
/argocd/ @YOUR_ORG/platform-team
```

---

## 2. CI gates (Stage 2) — tighten in this repo

| Today | Enterprise-style tightening |
|--------|------------------------------|
| Coverage **`fail_under = 70`** in [`pyproject.toml`](../pyproject.toml) (`[tool.coverage.report]`) | Raise to **80** (or org standard) once tests support it: `fail_under = 80`. |
| **Trivy** `exit-code: "0"` in [`reusable-docker-release.yml`](../.github/workflows/reusable-docker-release.yml) | Set **`exit-code: "1"`** and tune base image / `.trivyignore` so **CVEs fail the build** when you are ready. |
| **Codecov** `fail_ci_if_error: false` | Set **`true`** if Codecov is a required gate. |
| **SonarQube** | Keep **`sonarqube-gate`** on `main` with `SONAR_*` set so **quality gate blocks** Kind/EKS deploy (already wired in [`ci-cd.yml`](../.github/workflows/ci-cd.yml)). |
| **Secret scan in CI** | Add e.g. **TruffleHog** or **GitLeaks** as a workflow job on PRs (not in repo by default). |

---

## 3. Artifact and supply chain (Stage 3)

| Capability | In this repo | To reach “enterprise” parity |
|-------------|--------------|--------------------------------|
| **Image CVE scan** | Trivy + SARIF → Code scanning | Already present. |
| **Image signing** | Not configured | Add **Cosign** sign step after push; verify in cluster with admission policy (Kyverno/sigstore). |
| **SBOM** | Not generated in CI | Add **Syft** / **cyclonedx** in build job; attach as workflow artifact or to registry. |
| **Immutable tags** | GHCR uses **commit SHA** tag | Prefer SHA (or digest) in deploy; avoid `:latest` in prod. |

---

## 4. Separate “config” repo (GitOps split)

**Today:** Argo CD and Kubernetes YAML live **in this same repo** as the app (`ARGOCD_REPO_URL` points here).

**Enterprise pattern:** **App repo** (build, tests, Dockerfile) vs **platform / env repo** (only `k8s/`, `argocd/`, Helm values per env). See **[GITOPS_APP_CONFIG_SPLIT.md](GITOPS_APP_CONFIG_SPLIT.md)** for the split, drift behavior, and [`scripts/export-gitops-repo.sh`](../scripts/export-gitops-repo.sh).

---

## 5. Approvals and production (Stages 5–6)

| Control | Where | This repo |
|--------|--------|-----------|
| **Environment protection** | GitHub → *Settings* → *Environments* → `staging` / `production` | [`ci-cd.yml`](../.github/workflows/ci-cd.yml) already references **`staging`** and **`production`**; add **required reviewers** and **wait timer** for prod. |
| **Manual prod** | `workflow_dispatch` | **`deploy-prod-gcp-dr`** is already manual; restrict who can run workflows in org settings if needed. |
| **CAB / ServiceNow** | External | Process only; link deployments to tickets outside GitHub. |

---

## 6. Observability and audit (Stage 7)

| Area | Local demo | Enterprise |
|------|------------|--------------|
| **Metrics / dashboards** | Docker Compose: Prometheus + Grafana | In-cluster **kube-prometheus-stack** or vendor APM; keep `/metrics` contract. |
| **Logs** | App stdout JSON | Ship to org SIEM (Splunk, Datadog, CloudWatch). |
| **Alert routing** | [`alerts.yml`](../observability/prometheus/alerts.yml) — no Alertmanager receiver in Compose | Deploy **Alertmanager** → PagerDuty / Slack → ticket. |
| **Audit log** | GitHub **Audit log** (org) + **Immutable actions** where available | Enable for who changed branch rules / who approved deploy. |

---

## 7. Quick checklist (copy for onboarding)

- [ ] Branch protection on `main` + required checks from `ci.yml` / `ci-cd.yml`
- [ ] `CODEOWNERS` in repo root with real teams
- [ ] Secret scanning (+ push protection) enabled
- [ ] Sonar `SONAR_*` configured + quality gate enforced on `main`
- [ ] Decide Trivy **fail build** vs SARIF-only
- [ ] Coverage target aligned (`fail_under` in `pyproject.toml`)
- [ ] GitHub Environments: **required reviewers** for `production`
- [ ] (Optional) Second GitOps repo + Argo `repoURL` update
- [ ] (Optional) Cosign + SBOM in `reusable-docker-release.yml`

---

## Related docs

- [**GitOps: app vs config repo**](GITOPS_APP_CONFIG_SPLIT.md) — split, drift, export script
- [Enterprise pipeline narrative (7 stages)](enterprise-ci-cd-pipeline/README.md)
- [Architecture](ARCHITECTURE.md)
- [End-to-end GitHub](END_TO_END_GITHUB.md)
- [SonarQube setup](SONARQUBE.md)

If you tell us which items you want **implemented in YAML/code** first (e.g. Trivy fail, `fail_under` 80, Cosign stub, secret-scan job), we can apply those changes in a focused PR-style pass.
