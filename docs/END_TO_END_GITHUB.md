# End-to-end GitHub (GHCR-first)

This project is wired so **GitHub is the control plane** for source, CI/CD, container registry, and security signals—without requiring Docker Hub for the happy path.

## What “end-to-end GitHub” means here

| Area | Implementation |
|------|----------------|
| **Source** | GitHub repository |
| **CI** | `ci.yml` — reusable Python + Docker build (no push) |
| **CD** | `ci-cd.yml` on `main` — Python → build/Trivy → **push to GHCR** → **Kind deploy** (`deploy-kind`, same overlay as `make kind-apply`) → optional **Terraform** (`terraform-cloud-iac` if `TERRAFORM_CI_ENABLED=true`) → optional **EKS** if `EKS_STAGING_ENABLED` |
| **Registry** | **GitHub Container Registry** (`ghcr.io/<lowercase-owner>/financial-enterprise-asset-api`) using `GITHUB_TOKEN` |
| **Supply chain** | Trivy SARIF → GitHub Security / Code scanning |
| **Optional mirrors** | Docker Hub when `DOCKERHUB_*` secrets are set |

## Permissions

`ci-cd.yml` grants `packages: write` so the reusable release workflow can push to GHCR. Reusable workflow [reusable-docker-release.yml](../.github/workflows/reusable-docker-release.yml) also declares `packages: write`.

## Secrets (minimal vs enterprise)

**Minimal (GHCR only):** no container registry secrets required; `secrets: inherit` passes `GITHUB_TOKEN` implicitly for GHCR login.

**Optional mirror:** set `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` as documented in [CICD_REUSABLE.md](CICD_REUSABLE.md).

**Kind “staging” on CI:** **`deploy-kind`** runs on every `main` push after the image is on GHCR. It does **not** use Terraform (no VPC/EKS resources — only `kubectl` + `k8s/overlays/local`).

**Terraform on CI (optional):** set repository **Variable** **`TERRAFORM_CI_ENABLED`** = **`true`** to run **`terraform-cloud-iac`** (fmt, Checkov, `terraform validate` for `terraform/aws` and `terraform/gcp`). Use this when you are iterating on **AWS/GCP** infrastructure before apply. **Kind does not need it.**

**EKS staging (opt-in):** add **`EKS_STAGING_ENABLED`** = **`true`** and configure **`AWS_ROLE_ARN`** (OIDC) plus an EKS cluster matching the workflow. Without the variable, `deploy-staging` is skipped so `main` stays green without AWS.

**Cloud deploy (GKE prod path):** `GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_SERVICE_ACCOUNT` (and cluster names/regions matching your Terraform). `deploy-prod-gcp-dr` still **needs** a successful `deploy-staging`, so enable EKS staging or adjust that job’s `needs` if you run prod without EKS.

## Kubernetes image pull (private GHCR)

If the GHCR package is **private**, clusters need credentials (for example `imagePullSecrets` referencing a secret created from a GitHub PAT with `read:packages`, or a workload-specific pattern your org uses). Public packages pull without extra config.

## GitHub features to enable in a real org

- **Branch protection** on `main` (required status checks from `ci.yml` / `ci-cd.yml`).
- **Environments** (`staging`, `production`) with optional approvers — already referenced in workflows.
- **OIDC** to AWS/GCP — `id-token: write` is set on `ci-cd.yml` for federated auth patterns.
- **Dependabot** — [.github/dependabot.yml](../.github/dependabot.yml) bumps Actions and pip dependencies on a schedule.

## Related docs

- [CICD_REUSABLE.md](CICD_REUSABLE.md) — reusable workflow inputs and callers.
- [ARCHITECTURE.md](ARCHITECTURE.md) — platform diagram and components.
