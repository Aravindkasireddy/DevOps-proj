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

echo ""
echo "Argo CD installed."
echo "  UI (NodePort):  https://localhost:${NODE_PORT:-443}  (accept self-signed cert)"
echo "  UI (port-fwd):  kubectl port-forward svc/argocd-server -n argocd 8081:443"
echo "                  https://localhost:8081"
echo "  Username:       admin"
echo "  Password:       ${PASS}"
echo ""
echo "Install CLI: brew install argocd  # then: argocd login ..."
