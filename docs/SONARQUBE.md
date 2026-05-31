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
5. Push to **`main`** / **`develop`** or open a **PR** — workflow **SonarQube** runs when all three are set.

The workflow is skipped until `SONAR_TOKEN`, `SONAR_ORGANIZATION`, and `SONAR_PROJECT_KEY` exist (so forks without secrets do not fail).

## SonarQube Server (self-hosted)

1. Create a project and a **user token** on your SonarQube instance.
2. Add GitHub secrets:
   - `SONAR_TOKEN`
   - `SONAR_HOST_URL` — base URL of your server (e.g. `https://sonar.company.com`)
3. Set repo **Variables** `SONAR_ORGANIZATION` and `SONAR_PROJECT_KEY` as on the server.

Under the **SonarQube Scan** step in [`.github/workflows/sonarqube.yml`](../.github/workflows/sonarqube.yml), add to `env:`:

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

- [CICD_REUSABLE.md](CICD_REUSABLE.md) — Python / Docker reusable workflows (Sonar is a separate top-level workflow by design).
