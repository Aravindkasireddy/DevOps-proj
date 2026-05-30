# JFrog Artifactory — Optional enterprise registry

CI/CD **defaults to [GHCR](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)** (`ghcr.io/<owner>/financial-enterprise-asset-api`) using `GITHUB_TOKEN`. **Artifactory** is an optional mirror for teams that require JFrog RBAC, Xray, or air-gapped promotion workflows.

## Repository layout (Artifactory)

| Repo | Purpose |
|------|---------|
| `docker-dev-local` | CI snapshots from feature branches |
| `docker-staging-local` | Release candidates (CI pushes here when secrets are set) |
| `docker-prod-local` | Production-approved images |

## Image naming

```
${ARTIFACTORY_URL}/docker-prod-local/financial-enterprise/asset-api:${GIT_SHA}
```

GKE DR deploy in `ci-cd.yml` uses **GHCR** unless `ARTIFACTORY_URL` is set, in which case it pulls the **prod-local** path above (align with your promotion process).

## GitHub Actions secrets

| Secret | Description |
|--------|-------------|
| `ARTIFACTORY_URL` | e.g. `fin-enterprise.jfrog.io` (no `https://` for Docker login registry host — match your JFrog Docker subdomain) |
| `ARTIFACTORY_USER` | CI service account |
| `ARTIFACTORY_PASSWORD` | API key or reference token |

## Local login

```bash
docker login ${ARTIFACTORY_URL} -u ${ARTIFACTORY_USER} -p ${ARTIFACTORY_PASSWORD}
docker pull ${ARTIFACTORY_URL}/docker-prod-local/financial-enterprise/asset-api:latest
```

## Promotion flow (interview answer)

1. **Build** on merge to `main` → push to **GHCR** at commit SHA (+ `latest` on default branch).
2. **Scan** with Trivy; fail on Critical CVEs where policy requires it.
3. **Optional:** mirror the same digest to Artifactory `docker-staging-local` / `docker-prod-local` after QA sign-off (`workflow_dispatch`, environment gate, or JFrog promotion pipeline).
4. **Deploy** Kubernetes uses `kubectl set image` with either `ghcr.io/...` or Artifactory URL depending on environment variables / secrets.

## Xray (optional)

Enable JFrog Xray policy on `docker-prod-local` to block images with license violations or CVSS ≥ 7.
