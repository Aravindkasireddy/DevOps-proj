#!/usr/bin/env bash
# Create Kind cluster, build API image, load into nodes, optional metrics-server
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER_NAME="${KIND_CLUSTER_NAME:-fin-enterprise}"
IMAGE="financial-enterprise/asset-api:local"

command -v kind >/dev/null || { echo "Install kind: https://kind.sigs.k8s.io/"; exit 1; }
command -v docker >/dev/null || { echo "Docker is required"; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl is required"; exit 1; }

cd "$ROOT"

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "Kind cluster '$CLUSTER_NAME' already exists — skipping create"
else
  echo "Creating Kind cluster '$CLUSTER_NAME'..."
  kind create cluster --name "$CLUSTER_NAME" --config kind/kind-config.yaml
fi

kubectl cluster-info --context "kind-${CLUSTER_NAME}"

echo "Building and loading image ${IMAGE}..."
docker build -t "$IMAGE" -f docker/Dockerfile .
kind load docker-image "$IMAGE" --name "$CLUSTER_NAME"

if ! kubectl get deployment metrics-server -n kube-system &>/dev/null; then
  echo "Installing metrics-server (for HPA demos on other overlays)..."
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
  kubectl patch deployment metrics-server -n kube-system --type=json \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' || true
fi

echo ""
echo "Kind cluster ready."
echo "  kubectl apply (no Argo):  make kind-apply"
echo "  Full GitOps (Argo CD):    make argocd-up"
echo "  API via NodePort:         http://localhost:30080/health  (after deploy)"
