# SonarQube / SonarCloud

This repo runs **static analysis + coverage** in GitHub Actions using the official [**SonarSource/sonarqube-scan-action**](https://github.com/SonarSource/sonarqube-scan-action) and [`sonar-project.properties`](../sonar-project.properties) at the repository root.

## SonarQube Cloud (recommended for GitHub)

1. Sign in at [SonarQube Cloud](https://sonarcloud.io/) (free tier for public projects).
2. **Analyze a new project** → import **GitHub** → select **`DevOps-proj`** (or your fork).
3. Choose **With GitHub Actions** and copy:
   - **Organization key** (e.g. `aravindkasireddy`)
   - **Project key** (e.g. `aravindkasireddy_devops-proj`)
4. In GitHub: **Settings → Secrets and variables → Actions**
   - **New repository secret:** `SONAR_TOKEN` — token from SonarCloud (**My Account → Security** or the onboarding wizard).
   - **Variables** tab (not Encrypted): add  
     - `SONAR_ORGANIZATION` = your organization key  
     - `SONAR_PROJECT_KEY` = your project key  
5. **Where it runs:** With all three values set, the scan runs from **CI/CD** on every push to **`main`** (job **SonarQube (deploy gate)**) before **Kind** or **EKS** deploy; if the scan or quality gate fails, those deploy jobs do not run. The standalone **SonarQube** workflow runs on **`develop`** pushes, **PRs** to `main`/`develop`, and **workflow_dispatch** (so `main` is not scanned twice on push).

6. **Use only one analysis mode on SonarCloud.** This repo uses **GitHub Actions** (`sonarqube-scan-action`). In SonarCloud, open the project → **Administration** → **Analysis Method** (or **General Settings** → analysis / automatic analysis, depending on UI) and **turn off Automatic Analysis** so Sonar does not also scan the repo on every push from Sonar’s side. If both are on, the scanner fails with:  
   `You are running CI analysis while Automatic Analysis is enabled. Please consider disabling one or the other.`

The reusable scan **skips** (with a green notice) until `SONAR_TOKEN`, `SONAR_ORGANIZATION`, and `SONAR_PROJECT_KEY` exist; in that case the deploy gate still succeeds so **Kind/EKS** can run without Sonar configured. GitHub does not allow `secrets.*` in **job-level** `if:` expressions, so this repo gates inside a step instead.

## Troubleshooting

| Log / symptom | What to do |
|----------------|------------|
| `CI analysis while Automatic Analysis is enabled` | In SonarCloud: **disable Automatic Analysis** for this project (keep CI / GitHub Actions only). See the numbered setup step on Automatic Analysis above. |
| Quality Gate failed (exit code 3 after analysis completes) | Fix issues in SonarCloud, or temporarily set `sonar.qualitygate.wait=false` in `sonar-project.properties` (CI stays green; gate still visible in SonarCloud). |
| Invalid workflow / job never runs | Ensure job-level `if:` does not reference `secrets` (this repo uses a gate **step** instead). |

## SonarQube Server (self-hosted)

1. Create a project and a **user token** on your SonarQube instance.
2. Add GitHub secrets:
   - `SONAR_TOKEN`
   - `SONAR_HOST_URL` — base URL of your server (e.g. `https://sonar.company.com`)
3. Set repo **Variables** `SONAR_ORGANIZATION` and `SONAR_PROJECT_KEY` as on the server.

Under the **SonarQube Scan** step in [`.github/workflows/reusable-sonarqube-scan.yml`](../.github/workflows/reusable-sonarqube-scan.yml) (used by `sonarqube.yml` and **CI/CD**), add to `env:`:

```yaml
SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
```

(SonarQube Cloud does **not** need `SONAR_HOST_URL`; it is omitted by default.)

## What the CI job does

1. Checkout with **full history** (`fetch-depth: 0`) for blame/PR analysis.  
2. Install Python **3.12** and **`pip install -e ".[dev]"`**.  
3. Run **`pytest`** with **`coverage.xml`** (same layout as other CI).  
4. Run **SonarScanner** with coverage and paths from `sonar-project.properties` plus `-Dsonar.organization` / `-Dsonar.projectKey` from repo variables.

## Related

- [CICD_REUSABLE.md](CICD_REUSABLE.md) — Python / Docker reusable workflows; **CI/CD** also calls the reusable Sonar scan before Kind/EKS deploy.
