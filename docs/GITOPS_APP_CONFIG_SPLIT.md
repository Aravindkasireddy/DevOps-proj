# Split: application repo vs GitOps (configuration) repo

This document matches the task: **Argo CD watches only the configuration repository** so desired state lives in git and **drift** (manual `kubectl` edits, failed rollouts, image pins) shows up as **OutOfSync** in Argo CD until you reconcile or revert.

Your **GitOps** remote (manifests only): **[fin-enterprise-gitops](https://github.com/Aravindkasireddy/fin-enterprise-gitops)** — `https://github.com/Aravindkasireddy/fin-enterprise-gitops.git`

---

## What you are building

| Repository | Responsibility | Argo CD |
|--------------|----------------|---------|
| **Application** | Python/FastAPI source, tests, `Dockerfile`, CI that **builds and pushes** the container image to GHCR (or your registry) | Does **not** need to watch this repo for cluster YAML (optional: watch only for Helm chart if you later package that way). |
| **GitOps / config** | **Only** manifests Argo applies: `k8s/` (Kustomize), `argocd/` (Applications, AppProject), env-specific values, image tag/digest references | **Watches this repo**. Any change merged here is the truth; cluster should match. |

**Drift detection:** If someone changes the cluster without a git commit, Argo reports **OutOfSync** (and with **selfHeal**, it can revert drift—use carefully in prod).

---

## Target layout after split

### Application repo (example: `fin-enterprise-api`)

Suggested contents to **keep**:

- `app/`, `app/tests/`, `database/` (migrations), `pyproject.toml`, `docker/Dockerfile`, `docker-compose.yml` (local dev)
- `.github/workflows/` — `ci.yml`, build/push workflow; **no** long-lived cluster manifests required here
- `docs/` for app/API
- Optional: `Makefile` targets that only build image and run tests

**Remove or stop maintaining** (moved to GitOps repo):

- `k8s/`, `argocd/` (after cutover)

### GitOps repo (example: `fin-enterprise-gitops`)

Suggested contents:

```
fin-enterprise-gitops/
  README.md
  k8s/                    # copied from monorepo — overlays unchanged
  argocd/
    projects/
    applications/         # Application.spec.source.repoURL → THIS repo (self)
```

Each `Application` must set:

```yaml
spec:
  source:
    repoURL: https://github.com/Aravindkasireddy/fin-enterprise-gitops.git
    targetRevision: main
    path: k8s/overlays/local   # or staging / prod
```

Bootstrap (`kubectl apply` for AppProject + Applications) runs against the **GitOps** clone; `REPO_URL_PLACEHOLDER` is replaced with the **GitOps** HTTPS URL (same as today’s `ARGOCD_REPO_URL`, but semantically it is the **config** repo).

---

## How the new image reaches the cluster

Git no longer lives next to the Dockerfile, so pick **one** promotion pattern:

1. **Argo CD Image Updater** (common)  
   - Annotates the Application or Deployment; updater commits new digest/tag to the **GitOps** repo; Argo syncs.  
   - Good when you want automation without the app repo touching GitOps.

2. **CI in app repo commits to GitOps** (PAT / GitHub App)  
   - After push to GHCR, workflow runs `kustomize edit set image` in a checked-out GitOps repo and pushes a commit.  
   - Good when you want pipeline-controlled promotions per environment.

3. **Manual / release PR**  
   - Change image tag in GitOps `kustomization` or patch; merge; Argo syncs.  
   - Fine for demos and low frequency.

This monorepo does not ship Image Updater or cross-repo CI; add when you create the second repository.

---

## Migration steps (practical order)

1. **Create** the GitHub repo (empty is fine) — e.g. [Aravindkasireddy/fin-enterprise-gitops](https://github.com/Aravindkasireddy/fin-enterprise-gitops).

2. **Clone and seed** from this monorepo (`DevOps-proj`). **You must run the export script first** — otherwise `k8s/` and `argocd/` do not exist in the empty clone and `git add k8s` will fail.

   ```bash
   git clone https://github.com/Aravindkasireddy/fin-enterprise-gitops.git
   cd fin-enterprise-gitops
   /path/to/DevOps-proj/scripts/export-gitops-repo.sh "$(pwd)"
   git add k8s argocd README.md .gitignore
   git commit -m "chore: seed GitOps manifests from DevOps-proj"
   git push -u origin main
   ```

3. **Point Argo CD at the GitOps repo**

   ```bash
   export GITOPS_REPO_URL=https://github.com/Aravindkasireddy/fin-enterprise-gitops.git
   make argocd-bootstrap
   ```

4. **Verify** in Argo UI: Application source repo = **GitOps** URL; sync **Healthy**.

5. **Remove `k8s/` and `argocd/` from the application repo** only after the GitOps repo is the source of truth and teams agree (avoid two masters).

6. **Tighten branch protection** on **GitOps** `main` (required reviews for manifest changes)—often stricter than the app repo.

---

## Drift: what Argo compares

- **Git** = `fin-enterprise-gitops` at `targetRevision` (e.g. `main`).  
- **Live** = API server objects in the target namespace/cluster.  
- Difference → **OutOfSync**. With **automated selfHeal**, Argo reapplies git (reverts manual kubectl).

Ignored differences (example in `fin-enterprise-api-local.yaml`): `ignoreDifferences` on Deployment image when Kind loads a local image tag outside git—keep or drop when you move to digest-only from GHCR.

---

## Variables / scripts in this repo

| Name | Meaning |
|------|---------|
| `GITOPS_REPO_URL` | HTTPS URL of the **configuration** repo (preferred for bootstrap). |
| `ARGOCD_REPO_URL` | Legacy name; still works—same value as GitOps URL after split. |

| Script | Role |
|--------|------|
| [`scripts/export-gitops-repo.sh`](../scripts/export-gitops-repo.sh) | Copies `k8s/` + `argocd/` + starter `README.md` into a directory you turn into the GitOps repo. |
| [`scripts/argocd-bootstrap.sh`](../scripts/argocd-bootstrap.sh) | Substitutes `REPO_URL_PLACEHOLDER` with `GITOPS_REPO_URL` or `ARGOCD_REPO_URL`. |

---

## Related

- [KIND_ARGOCD.md](KIND_ARGOCD.md) — local Kind + Argo (update `ARGOCD_REPO_URL` / `GITOPS_REPO_URL` to the GitOps remote after split).  
- [ENTERPRISE_LEVEL.md](ENTERPRISE_LEVEL.md) — governance checklist including this split.

If you want the **application** side of this monorepo trimmed (delete `k8s/` here after export), say so explicitly—that is a **breaking** change for anyone still using single-repo Kind paths.
