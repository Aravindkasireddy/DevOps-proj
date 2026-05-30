#!/usr/bin/env bash
# Register Git repo + apply AppProject + Argo CD Applications (leaf apps; see root-app.yaml note)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER_NAME="${KIND_CLUSTER_NAME:-fin-enterprise}"

REPO_URL="${ARGOCD_REPO_URL:-}"
if [[ -z "$REPO_URL" ]]; then
  if git -C "$ROOT" remote get-url origin &>/dev/null; then
    REPO_URL=$(git -C "$ROOT" remote get-url origin)
    # Normalize SSH → HTTPS for Argo CD public repos
    if [[ "$REPO_URL" =~ ^git@github\.com:(.+)\.git$ ]]; then
      REPO_URL="https://github.com/${BASH_REMATCH[1]}.git"
    fi
  fi
fi

if [[ -z "$REPO_URL" ]] || [[ "$REPO_URL" == *"YOUR_"* ]]; then
  echo "Set your Git remote URL:"
  echo "  export ARGOCD_REPO_URL=https://github.com/<you>/financial-enterprise-devops-platform.git"
  exit 1
fi

kubectl config use-context "kind-${CLUSTER_NAME}" 2>/dev/null || true

echo "Using repo: $REPO_URL"

kubectl apply -f "$ROOT/argocd/projects/fin-enterprise-project.yaml"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Leaf Applications only (repo URL substituted here). We skip root-app.yaml:
# syncing argocd/applications from git would re-apply YAML that still contains
# REPO_URL_PLACEHOLDER in the repo. Use app-of-apps after templating or Helm if needed.
for f in "$ROOT/argocd/applications/"*.yaml; do
  [[ -f "$f" ]] || continue
  sed "s|REPO_URL_PLACEHOLDER|${REPO_URL}|g" "$f" > "$TMP/$(basename "$f")"
done

kubectl apply -f "$TMP"

echo ""
echo "Bootstrap applied. Watch sync:"
echo "  kubectl get applications -n argocd -w"
echo ""
echo "After sync, API: http://localhost:30080/health"
echo ""
echo "Load local image into Kind (required for financial-enterprise/asset-api:local):"
echo "  docker build -t financial-enterprise/asset-api:local -f docker/Dockerfile ."
echo "  kind load docker-image financial-enterprise/asset-api:local --name ${CLUSTER_NAME}"
