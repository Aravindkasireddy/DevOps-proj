#!/usr/bin/env bash
# Install Argo CD on the current kubectl context (Kind or remote)
set -euo pipefail
ARGOCD_VERSION="${ARGOCD_VERSION:-v2.13.2}"
CLUSTER_NAME="${KIND_CLUSTER_NAME:-fin-enterprise}"

if kubectl config current-context 2>/dev/null | grep -q "kind-${CLUSTER_NAME}"; then
  kubectl config use-context "kind-${CLUSTER_NAME}"
fi

echo "Installing Argo CD ${ARGOCD_VERSION}..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

echo "Waiting for Argo CD server..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# Expose server via port-forward friendly NodePort for Kind
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}' 2>/dev/null || true

NODE_PORT=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}' 2>/dev/null || echo "")
PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "n/a")

IS_KIND=false
if kubectl config current-context 2>/dev/null | grep -qE '^kind-'; then
  IS_KIND=true
fi

echo ""
echo "Argo CD installed."
if [[ "$IS_KIND" == true ]]; then
  echo ""
  echo "  *** Kind: use port-forward for the UI (NodePort is usually NOT reachable on localhost"
  echo "      because only selected ports are mapped in kind/kind-config.yaml). ***"
  echo ""
fi
echo "  UI (recommended on Kind):"
echo "    kubectl port-forward svc/argocd-server -n argocd 8081:443"
echo "    https://localhost:8081  (accept self-signed cert)"
echo ""
echo "  UI (NodePort — works on cloud / some single-node setups):"
echo "    https://localhost:${NODE_PORT:-<nodePort>}  (from: kubectl get svc argocd-server -n argocd)"
echo ""
echo "  Username:       admin"
echo "  Password:       ${PASS}"
echo ""
echo "Install CLI: brew install argocd  # then: argocd login ..."
