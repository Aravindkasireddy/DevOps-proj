#!/usr/bin/env bash
set -euo pipefail
CLUSTER_NAME="${KIND_CLUSTER_NAME:-fin-enterprise}"
kind delete cluster --name "$CLUSTER_NAME"
echo "Deleted Kind cluster: $CLUSTER_NAME"
