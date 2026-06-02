#!/usr/bin/env bash
# Seed a new GitOps-only repository from this monorepo (k8s/ + argocd/).
# Example (your GitOps repo):
#   git clone https://github.com/Aravindkasireddy/fin-enterprise-gitops.git && cd fin-enterprise-gitops
#   /path/to/DevOps-proj/scripts/export-gitops-repo.sh "$(pwd)"
#
# Then: git add . && git commit -m "Seed k8s and Argo CD manifests" && git push
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <path-to-empty-or-new-gitops-repo-checkout>"
  echo "Example: $0 ~/src/fin-enterprise-gitops"
  exit 1
fi

DEST="$(cd "$1" && pwd)"
if [[ ! -d "$DEST/.git" ]]; then
  echo "Warning: $DEST is not a git clone (.git missing). Files will still be copied."
fi

echo "Exporting k8s/ and argocd/ from $ROOT → $DEST"

rsync -a --delete "${ROOT}/k8s/" "${DEST}/k8s/"
rsync -a --delete "${ROOT}/argocd/" "${DEST}/argocd/"

cat > "${DEST}/README.md" <<'EOF'
# fin-enterprise-gitops

**GitOps / configuration repository** for Financial Enterprise Kubernetes workloads.

- Argo CD **watches this repo** (`repoURL` = this repository). Cluster drift vs `main` shows as **OutOfSync** in Argo CD.
- Application source, Dockerfile, and unit-test CI live in the **application** repository (build → container registry).

## Layout

| Path | Purpose |
|------|---------|
| `k8s/` | Kustomize base + overlays (`local`, `staging`, …) |
| `argocd/` | `AppProject`, `Application` manifests (`applications/*.yaml` use `REPO_URL_PLACEHOLDER` until bootstrap) |

## Bootstrap Argo CD (from a machine with kubectl to the cluster)

```bash
export GITOPS_REPO_URL="$(git remote get-url origin)"   # must be HTTPS for public repos; ssh→https if needed
# clone application repo only if you need scripts:
/path/to/app-repo/scripts/argocd-bootstrap.sh
```

Or copy `argocd/projects/` + templated `argocd/applications/` from this repo’s `scripts/argocd-bootstrap.sh` logic: substitute `REPO_URL_PLACEHOLDER` with this repo’s HTTPS URL, then `kubectl apply -f`.

## Image promotions

Update image digest or tag in `k8s/` (Kustomize) via PR here, or add **Argo CD Image Updater** / CI that commits to this repo after a successful app build.

EOF

cat > "${DEST}/.gitignore" <<'EOF'
.DS_Store
*.swp
.idea/
EOF

echo "Done. Next:"
echo "  cd \"$DEST\""
echo "  git status"
echo "  git add k8s argocd README.md .gitignore"
echo "  git commit -m \"chore: seed GitOps manifests\" && git push"
