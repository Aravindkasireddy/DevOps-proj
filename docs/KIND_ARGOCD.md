# Kind + Argo CD — Local GitOps Lab

Run the full **Kubernetes + GitOps** path on your laptop before touching AWS EKS.

## Prerequisites

| Tool | Install |
|------|---------|
| [kind](https://kind.sigs.k8s.io/) | `brew install kind` |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | `brew install kubectl` |
| [argocd CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/) | `brew install argocd` (optional) |
| Docker Desktop | Running |

## Flow overview

```
┌──────────────┐    git push     ┌─────────────┐    sync     ┌──────────────────┐
│  Your laptop │───────────────▶│ GitHub repo │────────────▶│ Argo CD (Kind)   │
│  kind-up.sh  │                │ k8s/overlays│             │ fin-enterprise-api-local│
└──────────────┘                └─────────────┘             └────────┬─────────┘
       │ build + kind load                                           │
       └──────────────────────────────────────────────────────────────┘
                    financial-enterprise/asset-api:local on worker nodes
```

## Option A — Full GitOps (recommended for interviews)

```bash
# 1. Push this repo to GitHub first
export ARGOCD_REPO_URL=https://github.com/<you>/financial-enterprise-devops-platform.git

# 2. Create cluster + load image
make kind-up

# 3. Install Argo CD + bootstrap applications
make argocd-up

# 4. Watch deployment
kubectl get applications -n argocd -w
kubectl get pods -n fin-enterprise-local
curl http://localhost:30080/health
```

Argo CD UI:

```bash
kubectl port-forward svc/argocd-server -n argocd 8081:443
# https://localhost:8081  user: admin
```

## Option B — kubectl only (before git push)

```bash
make kind-up
make kind-apply
curl http://localhost:30080/docs
```

## Makefile targets

| Target | Action |
|--------|--------|
| `make kind-up` | Create Kind cluster, build & load image |
| `make kind-apply` | `kubectl apply -k k8s/overlays/local` |
| `make kind-down` | Delete cluster |
| `make argocd-install` | Install Argo CD manifests |
| `make argocd-bootstrap` | AppProject + App-of-Apps (needs `ARGOCD_REPO_URL`) |
| `make argocd-up` | `argocd-install` + `argocd-bootstrap` |

## What gets deployed (local overlay)

| Resource | Purpose |
|----------|---------|
| `postgres` | In-cluster DB for Kind (no RDS needed) |
| `fin-enterprise-api` | API Deployment, `imagePullPolicy: Never`, local image |
| NodePort `30080` | http://localhost:30080 |
| No Ingress/HPA/ServiceMonitor | Avoids missing CRDs on bare Kind |

## Interview talking points

1. **Why Kind?** — Same Kubernetes API as EKS/GKE; fast feedback; CI can run `kind create cluster` in GitHub Actions.
2. **GitOps vs CI push** — Argo CD reconciles cluster to git; drift detection, rollback = revert commit.
3. **App-of-Apps** — `argocd/bootstrap/root-app.yaml` manages `argocd/applications/*.yaml`.
4. **ignoreDifferences** — Local image loaded via `kind load` isn’t in git; prevents sync loops.
5. **Promotion** — `fin-enterprise-api-local` → `fin-enterprise-api-staging` → prod overlays; same pattern as Artifactory image promotion.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `ImagePullBackOff` | `kind load docker-image financial-enterprise/asset-api:local --name fin-enterprise` |
| Argo `ComparisonError` / repo | Set `ARGOCD_REPO_URL`; ensure repo is public or add credentials in Argo CD |
| `/ready` database down | Wait for postgres pod: `kubectl logs -n fin-enterprise-local deploy/postgres` |
| OutOfSync on image | Expected — `ignoreDifferences` on Deployment image; or commit image tag for real envs |

## Clean up

```bash
make kind-down
```
