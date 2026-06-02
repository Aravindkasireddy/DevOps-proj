.PHONY: help install lint test sast docker-up docker-down tf-fmt checkov \
        kind-up kind-apply kind-down argocd-install argocd-bootstrap argocd-up

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

install: ## Install Python deps (dev)
	pip install -e ".[dev]"

lint: ## Ruff + mypy
	ruff check app
	ruff format --check app
	mypy app

test: ## Run unit tests with coverage
	pytest app/tests --cov=app --cov-report=term-missing

sast: ## Bandit SAST
	bandit -r app -c pyproject.toml

docker-up: ## Start local stack (API + DB + observability)
	cp -n .env.example .env 2>/dev/null || true
	docker compose up -d --build

docker-down:
	docker compose down -v

tf-fmt: ## Format Terraform
	terraform fmt -recursive terraform/

checkov: ## Scan IaC with Checkov
	checkov -d terraform/ --config-file checkov.yaml

pre-commit:
	pre-commit run --all-files

kind-up: ## Create Kind cluster, build & load financial-enterprise/asset-api:local
	chmod +x scripts/*.sh
	./scripts/kind-up.sh

kind-apply: ## Deploy local overlay with kubectl (no Argo CD)
	./scripts/kind-apply.sh

kind-down: ## Delete Kind cluster
	./scripts/kind-down.sh

argocd-install: ## Install Argo CD on current cluster
	./scripts/argocd-install.sh

argocd-bootstrap: ## Apply AppProject + Applications (set GITOPS_REPO_URL or ARGOCD_REPO_URL)
	./scripts/argocd-bootstrap.sh

argocd-up: argocd-install argocd-bootstrap ## Install Argo CD and bootstrap GitOps apps
