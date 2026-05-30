#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -d .git ]]; then
  git init -b main
  echo "Git repository initialized on branch main"
fi

echo "Next steps:"
echo "  1. Create GitHub repo: gh repo create financial-enterprise-devops-platform --private --source=. --remote=origin"
echo "  2. Configure secrets: DOCKERHUB_*, ARTIFACTORY_*, AWS_ROLE_ARN, GCP_*"
echo "  3. git add . && git commit -m 'Initial Financial Enterprise DevOps platform' && git push -u origin main"
