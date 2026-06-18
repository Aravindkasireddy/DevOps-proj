📊 USAA Enterprise Use Case: GitOps DevSecOps & Canary Releases (ArgoCD + Argo Rollouts)

This document provides a detailed, end-to-end technical explanation of how USAA implemented an enterprise-grade GitOps continuous deployment pipeline with DevSecOps gating and automated Canary rollouts on AWS EKS, achieving safe, compliance-audited deployments.

Use this reference to prepare for interviews and explain this architecture step-by-step.

---

## 📋 Project Summary

| Field | Details |
| :--- | :--- |
| **Project Name** | GitOps DevSecOps Pipeline & Canary Releases |
| **Company** | USAA (United Services Automobile Association) |
| **Industry** | Financial Services / Insurance |
| **My Role** | DevOps Engineer — Cloud Platform Team |
| **Reporting To** | DevOps Engineering Manager (Platform Infrastructure) |
| **Project Duration** | ~8–10 weeks (2 to 2.5 months) |
| **Infrastructure** | AWS EKS, ArgoCD, Argo Rollouts, Prometheus, GitHub Actions, Trivy, Kyverno, SonarQube, AWS Secrets Manager |
| **Communication** | Microsoft Teams |
| **Ticketing** | Jira (Sprint Tracking) + ServiceNow (ITSM Release & Incident Management) |

---

## 🏢 Team Structure & Reporting

```text
                    ┌──────────────────────────┐
                    │  VP of Engineering        │
                    │  (Reports to CTO)         │
                    └────────────┬─────────────┘
                                 │
                    ┌────────────▼─────────────┐
                    │  Director of Platform     │
                    │  Engineering              │
                    └────────────┬─────────────┘
                                 │
                    ┌────────────▼─────────────┐
                    │  DevOps Engineering       │
                    │  Manager (My Manager)     │
                    └────────────┬─────────────┘
                                 │
            ┌────────────────────┼────────────────────┐
            ▼                    ▼                    ▼
    [ Sr. DevOps Eng ]    [ DevOps Eng (Me) ]   [ Jr. DevOps Eng ]
```

### Who I Report To
*   **Direct Manager**: DevOps Engineering Manager (Platform Infrastructure)
*   **Daily Standups**: Scrum Master runs the daily standup. I report progress, pipeline updates, and blockers.
*   **Sprint Reviews**: I demo automated rollbacks and Kyverno policy blocks to the Platform Director and Security Governance Leads every 2 weeks.

---

## 👥 Cross-Collaboration Teams & Team Members

### Core Project Team (8 People)

| Role | Name (Example) | Responsibility | Interaction Frequency |
| :--- | :--- | :--- | :--- |
| **DevOps Engineer (Me)** | Aravind K. | ArgoCD Application templates, Argo Rollouts config, GitHub Actions workflows, Kyverno policies | Daily |
| **Sr. DevOps Engineer** | Michael R. | Deployment security review, EKS RBAC structure approval, architectural validation | Daily |
| **Jr. DevOps Engineer** | Sarah L. | Prometheus metric integration, Alertmanager alerts, Grafana dashboard creation | Daily |
| **Security Architect** | David P. | Defining SonarQube quality gates, vulnerability severity thresholds, Kyverno compliance policies | 3–4x/week |
| **Release Manager** | Sarah L. | ServiceNow release template definitions, change advisory board alignment | Weekly |
| **QA Lead** | Maria G. | Executing load test suites during Canary phases, validating failback logic | 2–3x/week |
| **Scrum Master** | Kevin T. | Sprint planning, standup facilitation, blocker removal | Daily |
| **Product Owner** | Lisa M. | Microservice onboarding prioritization, business feature release roadmap alignment | Weekly |

---

## 🏆 Achievements

*   **94% Reduction in Deployment Failure Impact:** Automated rollback based on Prometheus performance metrics restricted errors to under 10% of users.
*   **Zero-Downtime Releases:** Replaced traditional blue-green rollouts with incremental canary traffic steering (10% -> 50% -> 100%) via Argo Rollouts.
*   **100% Secure Pipeline Compliance:** Enforced SonarQube quality gates and Trivy container scanning, failing builds automatically on critical CVEs.
*   **Zero Insecure Pods:** Deployed Kyverno policies blocking run-as-root containers, host namespace sharing, and unapproved registries.
*   **Automated Release Audits:** Configured ArgoCD sync status events to automatically update ServiceNow standard deployment tickets.

---

## 🏗️ The Architecture Landscape

To guarantee secure, automated deployments, we decoupled the CI pipeline from the CD pipeline:

```
                            GITOPS & DEVSECOPS LOGICAL PIPELINE
                            ═══════════════════════════════════
  
    [ App Developer Commits Code ]
                 │
                 ▼
    ┌───────────────────────────┐
    │    GitHub Actions (CI)    │ ◄── [ Trivy Container Scan ] & [ SonarQube SAST ]
    └────────────┬──────────────┘
                 │ (If passes gates: Build & Push Image)
                 ▼
    [ Amazon ECR Registry ] 
                 │
                 ▼ (Commit new tag to Config Repo)
    [ GitOps Manifest Repo ]
                 │
                 ▼ (Pull Configuration)
    [ ArgoCD Controller ] (Runs on EKS cluster)
                 │
                 ▼ (Syncs Manifests)
    [ Argo Rollouts Controller ]
                 │
                 ├─────► [ Canary Service: 10% Traffic ] ──► (Prometheus Queries metric checks)
                 │                                                │
                 │                                        (Healthy? Yes)
                 │                                                │
                 └─────► [ Prod Service: 100% Traffic ] ◄─────────┘
```

### Key Components:
*   **GitHub Actions (CI):** Builds application code, executes SonarQube SAST scanning, runs Trivy container scans, and commits updated Helm values to the GitOps repository.
*   **ArgoCD (CD):** A declarative GitOps controller running in EKS that continuously syncs the EKS cluster state with the GitOps configuration repo.
*   **Argo Rollouts:** A Kubernetes controller replacing standard Deployments with Canary capabilities, analyzing Prometheus metrics during rollouts.
*   **Kyverno Policy Engine:** Kubernetes-native admission controller validating resource compliance (e.g. blocking privileged containers).
*   **Prometheus & Grafana:** Monitors microservice HTTP status codes, latency, and system load, providing feedback to Argo Rollouts.

---

## ⚠️ The Problem: Manual Deployments & Untrusted code

USAA's microservices faced three primary deployment issues:

1.  **"Push-based" Pipeline Vulnerabilities:** Jenkins pipelines previously used cluster administrative credentials (`kubeconfig`) to push updates, exposing EKS master controls to CI runner vulnerabilities.
2.  **All-or-Nothing Deployments (Big Bang):** Kubernetes standard rolling updates replaced pods sequentially but routed traffic immediately. If a new image had a silent memory leak or database bug, 100% of users faced failures before rollback could complete manually.
3.  **Containers Running as Root:** Lack of policy enforcement allowed developers to deploy pods running as `root`, creating container escape hazards violating financial security audits.

---

## 🔄 End-to-End Automated Deployment Flow

Here is exactly how code transitions from git to live traffic securely:

### 1. The CI DevSecOps Guardrails
*   A developer commits code. GitHub Actions triggers the build workflow.
*   **SonarQube SAST:** Scans the codebase. If test coverage falls below 80% or any security vulnerability is found, the workflow aborts.
*   **Trivy SCA:** Scans the generated Docker image. If any `CRITICAL` vulnerability is found, the build fails.
*   If both pass, the image is pushed to ECR and a pull request updates the image tag in the GitOps git repository.

### 2. GitOps Sync via ArgoCD
*   ArgoCD detects the change in the GitOps repository.
*   Since ArgoCD pulls configuration, EKS credentials never leave the cluster (no ingress ports needed).
*   ArgoCD validates the files and initiates a cluster sync.

### 3. Progressive Delivery with Argo Rollouts
*   Argo Rollouts intercepts the deployment. It spins up a Canary pod running the new version.
*   It configures the ALB/Ingress controller to route 10% of traffic to the Canary pod, leaving 90% on the stable version.
*   **Metric Analysis:** Argo Rollouts initiates an `AnalysisRun`. It queries Prometheus every 30 seconds for the application's HTTP error rate.
*   **Auto-Rollback:** If Prometheus reports a 5xx error rate above 1% or p99 latency above 500ms, the analysis fails. Argo Rollouts instantly redirects 100% of traffic to the stable pods and tears down the Canary.
*   **Promotion:** If the analysis stays healthy for 5 minutes, traffic is promoted to 50%, then 100%.

---

## ☁️ AWS & Open-Source Tools Used

| Tool | Role in This Project | Why We Chose It |
| :--- | :--- | :--- |
| **ArgoCD** | Declarative GitOps continuous delivery controller | Restricts Kubernetes administrative access inside the cluster |
| **Argo Rollouts** | Progressive delivery controller enabling Canary releases | Out-of-the-box integration with Prometheus metric analysis |
| **Kyverno** | Kubernetes admission policy controller | Writes policies using standard Kubernetes YAML rather than Rego |
| **Prometheus** | Aggregates microservice performance metrics | Real-time querying allows instant rollback detection |
| **Trivy** | Vulnerability scanner for container images | Fast, lightweight, easily integrated into CI workflows |
| **SonarQube** | Static Application Security Testing (SAST) platform | Enterprise standard for code quality and security analysis |
| **Amazon EKS** | Container hosting platform | Production standard for running resilient Kubernetes systems |

---

## 🛠️ My Contribution as a DevOps Engineer

### What I Built

| Deliverable | Description |
| :--- | :--- |
| **ArgoCD Configuration** | Setup the ArgoCD installation and declared [ApplicationSet](file:///Users/aravind/Desktop/Devops/DevOps-proj/DevOps-use-cases/gitops_devsecops/kubernetes/argo-appset.yaml) resources |
| **Argo Rollout manifests** | Created the progressive [rollout.yaml](file:///Users/aravind/Desktop/Devops/DevOps-proj/DevOps-use-cases/gitops_devsecops/kubernetes/argo-rollout.yaml) and the analysis metric configurations |
| **Kyverno Policies** | Authored cluster policies ([kyverno-policy.yaml](file:///Users/aravind/Desktop/Devops/DevOps-proj/DevOps-use-cases/gitops_devsecops/kubernetes/kyverno-policy.yaml)) requiring non-root execution |
| **GitHub Actions Pipeline** | Programmed CI workflows enforcing SonarQube scans, Trivy scans, and GitOps commits |
| **ITSM Integration webhook** | Configured notification routing from ArgoCD to ServiceNow table APIs |

### What I Did NOT Build (Boundaries)

| Area | Who Built It | My Role |
| :--- | :--- | :--- |
| **Microservice code & Unit Tests** | App Developers | I configured the CI pipeline to run their tests and compile code |
| **Vulnerability remediation** | App Team Leads | I blocked pipelines; developers fixed the security vulnerabilities |
| **Prometheus server hosting** | Monitoring Platform Team | I queried their centralized Prometheus endpoints |

---

## 🔒 DevOps Engineer Boundaries

### ✅ My Lane (I Own This)

```text
GitOps Pipelines Configuration ─────────── I write ArgoCD applications and sync schedules
Canary Release Rules & Analysis ────────── I define traffic routing schedules and Prometheus metrics
Kubernetes Cluster Governance   ────────── I write Kyverno admission rules to protect the cluster
CI Pipeline Security Gates      ────────── I integrate Trivy and SonarQube steps in GitHub workflows
```

### 🚫 Not My Lane (I Collaborate But Don't Own)

```text
Microservice Code Vulnerabilities ──────── Developers fix security flaws and test coverage issues
Prometheus Monitoring Infrastructure ───── Platform metrics team manages the cluster Grafana servers
ServiceNow Incident Classification ─────── ITSM operations team configures standard ticket types
```

---

## 📅 Project Duration & Timeline (8–10 Weeks)

### Phase 1: Assessment & Pipeline Setup (Weeks 1–2)
* Review current deployment pain points and verify security requirements with compliance.
* Install ArgoCD and Argo Rollouts controllers in non-production EKS clusters.
* Structure GitOps manifest repository layouts.

### Phase 2: DevSecOps CI Gating (Weeks 3–4)
* Write GitHub Actions pipelines with SonarQube quality gates.
* Integrate Trivy container vulnerability scanning in image build phases.
* Set up Kyverno policies in EKS to audit and block privileged containers.

### Phase 3: Canary Delivery Configuration (Weeks 5–6)
* Define Argo Rollouts `AnalysisTemplates` targeting Prometheus metric endpoints.
* Migrate claims microservice deployments from standard K8s Deployments to Rollouts.
* Establish automated traffic steering using EKS ingress controllers.

### Phase 4: ServiceNow & Alerting Integration (Weeks 7–8)
* Configure webhook handlers to log ArgoCD promotions to ServiceNow release tickets.
* Implement Microsoft Teams alerts reporting rollout state updates.
* Execute dry-run deployments in dev to confirm auto-rollback behavior during synthetic failure injections.

### Phase 5: Production Rollout & Go-Live (Weeks 9–10)
* Obtain approval from CAB and deploy ArgoCD configurations to the production cluster.
* Run initial canary rollouts on a single low-impact microservice.
* Fully transition all 25 microservices to the GitOps DevSecOps pipeline.

---

## 🔍 Step-by-Step Technical Deep-Dive

### Step 1: Kyverno Cluster Policy
We configure a Kyverno ClusterPolicy to enforce security rules at EKS Admission time, blocking any pod that attempts to run as root:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-root-execution
  annotations:
    policies.kyverno.io/title: Restrict Root User Execution
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: validate-run-as-non-root
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "USAA Security Policy Violation: Pods must configure runAsNonRoot to true."
        pattern:
          spec:
            securityContext:
              runAsNonRoot: true
```

### Step 2: Argo Rollout & Metric Analysis
We configure the `Rollout` object with traffic steps and a Prometheus query evaluating error rates:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: claims-api-rollout
  namespace: banking
spec:
  replicas: 5
  strategy:
    canary:
      analysis:
        templates:
          - templateName: claims-error-rate-analysis
        args:
          - name: service-name
            value: claims-api-service
      steps:
        - setWeight: 10
        - pause: { duration: 5m }
        - setWeight: 50
        - pause: { duration: 5m }
```

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: claims-error-rate-analysis
  namespace: banking
spec:
  metrics:
    - name: http-error-rate
      interval: 30s
      successCondition: result[0] < 0.01
      failureLimit: 3
      provider:
        prometheus:
          address: http://prometheus-k8s.monitoring.svc.cluster.local:9090
          query: |
            sum(rate(http_requests_total{status=~"5.*",service="{{args.service-name}}"}[2m])) 
            / 
            sum(rate(http_requests_total{service="{{args.service-name}}"}[2m]))
```

---

## 🚨 ITSM Incident Management Flow

To maintain traceability, ArgoCD deployment phases are reported directly to ServiceNow.

### ServiceNow Ticket Mockup
When a rollout triggers an automatic rollback, the alerting system logs a ticket:

```
INCIDENT TICKET: INC-0029817
--------------------------------------------------------------------------------
Short Description: EKS Canary Deployment Auto-Rollback: claims-api
Assignment Group:  Platform-DevOps-Team
Status:            Resolved
Priority:          2 - High
Description:       
Argo Rollouts detected HTTP error rates exceeding the 1% threshold during the 10%
canary traffic phase for deployment 'claims-api'. Metric analysis failed 3 consecutive
evaluations in Prometheus. Argo Rollouts automatically terminated the canary pods and
redirected 100% of user traffic to stable pods running v1.4.2.

Resolution:
Deployment rolled back automatically within 30 seconds of threshold violation. No user
downtime occurred. Incident assigned to development squad to investigate the 5xx status
codes in claims-api v1.4.3 container logs.
--------------------------------------------------------------------------------
```

---

## 💬 Interview Preparation (Q&A)

### Q1: What is GitOps, and why is the pull-based model more secure?
**Answer:** GitOps is an operating model where git is the single source of truth for infrastructure and application state. In traditional push-based CI/CD (like Jenkins), the runner needs access keys (`kubeconfig`) to log in and deploy. If the CI runner is compromised, attackers gain full access to the cluster. In a pull-based model (like ArgoCD), the ArgoCD controller runs inside EKS and pulls configurations from git. The cluster credentials never leave the cluster, reducing the attack surface.

### Q2: How does Argo Rollouts perform Canary releases, and how does rollback work?
**Answer:** Argo Rollouts replaces standard Kubernetes Deployments. During a release, it spins up a Canary pod alongside existing pods and routes a small percentage of traffic (e.g., 10%) using an ingress controller or service mesh. It then runs an `AnalysisRun` querying Prometheus for metrics like latency or 5xx errors. If metrics violate thresholds, Argo Rollouts aborts the release, shifts traffic back to the old pods, and terminates the canary, completing a zero-downtime automated rollback.

### Q3: What is Kyverno and why do we use it in EKS?
**Answer:** Kyverno is a Kubernetes-native policy engine. It allows us to define admission control rules as standard Kubernetes declarations (CRDs) without writing complex code (like OPA Rego). We use Kyverno to enforce security best practices at USAA, such as blocking pods that try to run as root, requiring resource limits, ensuring images come only from our private ECR registry, and requiring read-only root filesystems.
