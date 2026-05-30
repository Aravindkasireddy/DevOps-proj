#!/usr/bin/env bash
# Direct kubectl deploy to Kind (no Argo CD) — useful before git push
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER_NAME="${KIND_CLUSTER_NAME:-fin-enterprise}"

kubectl config use-context "kind-${CLUSTER_NAME}"
kubectl apply -k "$ROOT/k8s/overlays/local"
kubectl rollout status deployment/postgres -n fin-enterprise-local --timeout=120s
kubectl rollout status deployment/fin-enterprise-api -n fin-enterprise-local --timeout=180s

echo ""
echo "Financial Enterprise API (direct apply):"
echo "  Health:  http://localhost:30080/health"
echo "  Docs:    http://localhost:30080/docs"
echo "  Pods:    kubectl get pods -n fin-enterprise-local"
