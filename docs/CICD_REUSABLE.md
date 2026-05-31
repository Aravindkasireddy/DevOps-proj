# Reusable GitHub Actions workflows

This repo uses **`workflow_call`** so Python checks and Docker build/push live in **one place** and are invoked from `ci.yml` and `ci-cd.yml`.

**Primary registry:** [GitHub Container Registry (GHCR)](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry) using `GITHUB_TOKEN` — see [END_TO_END_GITHUB.md](END_TO_END_GITHUB.md).

## Files

| Workflow | Purpose |
|----------|---------|
| [reusable-python-ci.yml](../.github/workflows/reusable-python-ci.yml) | Ruff, MyPy, Bandit, pytest + optional Codecov |
| [reusable-docker-pr-build.yml](../.github/workflows/reusable-docker-pr-build.yml) | Docker build only (no push, no Trivy) — PR CI |
| [reusable-docker-release.yml](../.github/workflows/reusable-docker-release.yml) | Build, Trivy SARIF, push **GHCR** + optional Docker Hub mirror |

## Callers

| Caller | Invokes |
|--------|---------|
| `ci.yml` | `reusable-python-ci` → `reusable-docker-pr-build` |
| `ci-cd.yml` | `reusable-python-ci` → `reusable-docker-release` → **Kind** (`deploy-kind`, default “staging” on runner) → optional **`terraform-cloud-iac`** if `TERRAFORM_CI_ENABLED=true` → optional EKS (`deploy-staging`, `EKS_STAGING_ENABLED`) |

## Caller syntax

```yaml
jobs:
  python-ci:
    uses: ./.github/workflows/reusable-python-ci.yml
    secrets: inherit
    with:
      python-version: "3.12"
      upload-codecov: true

  docker:
    needs: [python-ci]
    uses: ./.github/workflows/reusable-docker-release.yml
    secrets: inherit
    with:
      package-name: financial-enterprise-asset-api
      dockerhub-image-path: financial-enterprise/asset-api
```

- **`secrets: inherit`** passes repository secrets to the reusable workflow. GHCR push does **not** require extra secrets; optional Docker Hub login uses `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` when set.
- Reusable workflows that declare `secrets:` under `workflow_call` only receive secrets the **child** declares; `inherit` maps matching names.

## Inputs (`reusable-python-ci`)

| Input | Default | Meaning |
|-------|---------|---------|
| `python-version` | `3.12` | Interpreter for setup-python |
| `upload-codecov` | `true` | Upload `coverage.xml` (skipped when `false`) |

## Inputs (`reusable-docker-release`)

| Input | Default | Meaning |
|-------|---------|---------|
| `package-name` | `financial-enterprise-asset-api` | Image name under `ghcr.io/<owner>/` |
| `dockerhub-image-path` | `financial-enterprise/asset-api` | `namespace/image` on Docker Hub when mirroring |

## Image tags (CD)

`reusable-docker-release` tags images with the **full** `github.sha` plus `latest` on the default branch so `kubectl set image …:${{ github.sha }}` matches the registry.

## Extending

- **Another service repo:** `uses: your-org/DevOps-proj/.github/workflows/reusable-python-ci.yml@main` (path must exist on default branch).
- **Composite actions:** For shared *steps* (e.g. “install Python deps”) use `.github/actions/name/action.yml` — smaller reuse unit than full workflows.

## GitLab equivalent

| GitHub reusable workflow | GitLab |
|--------------------------|--------|
| `workflow_call` + `uses:` | `include: project: ... file: templates/python.yml` + `extends` |
