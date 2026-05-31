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
# 1. Push this repo to GitHub first (same URL as your origin)
export ARGOCD_REPO_URL=https://github.com/Aravindkasireddy/DevOps-proj.git

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
# password (initial install):
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

After `make argocd-install` / `make argocd-up`, the install script also prints this password to the terminal.

**Why not `https://localhost:<NodePort>` on Kind?** This cluster’s `kind/kind-config.yaml` only maps a few **host** ports (e.g. `30080` for the API) into the Kind node. Argo’s **HTTPS NodePort** (often `30xxx`) is **not** mapped, so your browser cannot reach it on `localhost`. **Port-forward always works.** On a real cloud LB or a VM with a routable node IP, NodePort (or Ingress) is fine.

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
3. **App-of-Apps** — `argocd/bootstrap/root-app.yaml` is a reference pattern; bootstrap applies **leaf** `argocd/applications/*.yaml` with your repo URL substituted so Argo never syncs unresolved `REPO_URL_PLACEHOLDER` from git.
4. **ignoreDifferences** — Local image loaded via `kind load` isn’t in git; prevents sync loops.
5. **Promotion** — `fin-enterprise-api-local` → `fin-enterprise-api-staging` → prod overlays; image tags move with overlays (e.g. GHCR digest or `kubectl set image` in CI).

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Argo UI / `https://localhost:30xxx` hangs | On Kind, use **port-forward** (see above); NodePort is not published to the host unless you add it to `kind/kind-config.yaml` `extraPortMappings`. |
| `ImagePullBackOff` | `kind load docker-image financial-enterprise/asset-api:local --name fin-enterprise` |
| Argo `ComparisonError` / repo | Set `ARGOCD_REPO_URL`; ensure repo is public or add credentials in Argo CD |
| `/ready` database down | Wait for postgres pod: `kubectl logs -n fin-enterprise-local deploy/postgres` |
| OutOfSync on image | Expected — `ignoreDifferences` on Deployment image; or commit image tag for real envs |

## CI/CD on GitHub (`ci-cd.yml`)

On every push to **`main`**, after the image is pushed to **GHCR**, the **`Deploy to Kind (CI)`** job:

1. Creates a **Kind** cluster using `kind/kind-config.yaml` (same topology as local).
2. **`docker pull`** `ghcr.io/<lowercase-owner>/financial-enterprise-asset-api:<commit-sha>`, tags it as **`financial-enterprise/asset-api:local`**, and **`kind load`** so it matches `k8s/overlays/local`.
3. Runs **`kubectl apply -k k8s/overlays/local`** and waits for Postgres + API rollouts.
4. Hits **`http://127.0.0.1:30080/health`** on the runner (port map from `kind-config.yaml`).

**EKS staging** in the same workflow is **off by default**. Turn it on with repo **Variable** `EKS_STAGING_ENABLED` = `true` and real AWS/EKS wiring — see [END_TO_END_GITHUB.md](END_TO_END_GITHUB.md).

**Terraform in CI** is **off by default** (`TERRAFORM_CI_ENABLED` unset). Kind deploy does **not** use it; set **`TERRAFORM_CI_ENABLED=true`** when you want fmt / Checkov / validate for **AWS/GCP** in Actions.

## Clean up

```bash
make kind-down
```
