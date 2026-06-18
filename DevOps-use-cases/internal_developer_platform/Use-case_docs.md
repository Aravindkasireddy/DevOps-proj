📊 USAA Enterprise Use Case: Internal Developer Platform (Backstage) & Self-Service Golden Paths

This document provides a detailed, end-to-end technical explanation of how USAA implemented Spotify Backstage as an Internal Developer Platform (IDP) to enable self-service microservice bootstrapping and cloud provisioning, reducing resource delivery times from 5 days to 3 minutes.

Use this reference to prepare for interviews and explain this architecture step-by-step.

---

## 📋 Project Summary

| Field | Details |
| :--- | :--- |
| **Project Name** | Internal Developer Platform & Golden Paths |
| **Company** | USAA (United Services Automobile Association) |
| **Industry** | Financial Services / Insurance |
| **My Role** | DevOps Platform Engineer — Delivery Automation Enablement Team |
| **Reporting To** | Lead DevOps Infrastructure Engineer (Platform Infrastructure Org) |
| **Project Duration** | ~10–12 weeks (2.5 to 3 months) |
| **Infrastructure** | Spotify Backstage, AWS EKS, Crossplane, Terraform Enterprise, GitHub Enterprise, ArgoCD, ServiceNow Table APIs, Microsoft Teams webhooks |
| **Communication** | Microsoft Teams |
| **Ticketing** | Jira (Sprint Tracking) + ServiceNow (ITSM Incident & Change Management) |

---

## 🏢 Team Structure & Reporting

```text
                    ┌──────────────────────────┐
                    │  VP of Engineering        │
                    │  (Reports to CTO)         │
                    └────────────┬─────────────┘
                                 │
                    ┌────────────▼─────────────┐
                    │  Engineering Manager     │
                    │  (Platform Infrastructure)│
                    └────────────┬─────────────┘
                                 │
                    ┌────────────▼─────────────┐
                    │  Lead DevOps             │
                    │  Infrastructure Engineer  │
                    └────────────┬─────────────┘
                                 │
            ┌────────────────────┼────────────────────┐
            ▼                    ▼                    ▼
    [ Sr. DevOps Eng ]    [ DevOps Eng (Me) ]   [ Jr. DevOps Eng ]
```

### Who I Report To
*   **Direct Manager**: Lead DevOps Infrastructure Engineer (Platform Infrastructure Org)
*   **Daily Standups**: Scrum Master runs the daily standup. I report progress, template configurations, and blockers to the Lead DevOps Infrastructure Engineer.
*   **Sprint Reviews**: I demo self-service repo creations, database provisioning runs, and catalog integrations to the Engineering Manager (Platform Infrastructure Org) and Enterprise Architecture Board every 2 weeks.

---

## 👥 Cross-Collaboration Teams & Team Members

### Core Project Team (8 People)

| Role | Name (Example) | Responsibility | Interaction Frequency |
| :--- | :--- | :--- | :--- |
| **DevOps Engineer (Me)** | Aravind K. | Backstage Golden Path templates, Crossplane provider configurations, ServiceNow API integrations, ArgoCD setup | Daily |
| **Sr. DevOps Engineer** | Michael R. | Platform security architecture validation, RBAC approval, review of AWS provisioning policies | Daily |
| **Jr. DevOps Engineer** | Sarah L. | Backstage UI styling, catalog metadata collection, CloudWatch metrics dashboards | Daily |
| **Enterprise Security Lead** | David P. | Reviewing base templates for security standards, IAM role boundaries, Docker base image compliance | 3–4x/week |
| **ITSM Lead Developer** | Sarah L. | ServiceNow Change ticket automation APIs, sandbox environment setups | Weekly |
| **QA Engineer** | Maria G. | Stress testing portal load, validating scaffolding success rates, verifying database connectivity | 2–3x/week |
| **Scrum Master** | Kevin T. | Sprint planning, standup facilitation, blocker removal | Daily |
| **Product Owner** | Lisa M. | Gathering requirements from development squads, backlog priority definition | Weekly |

---

## 🏆 Achievements

*   **99.9% Faster Onboarding:** Reduced developer setup time for new microservices from 5 business days (Jira ticket queue wait) to under 3 minutes.
*   **100% Policy-Compliant Repositories:** Standardized project skeletons by embedding automated security scanning (Trivy), linting, and Helm values directly into Golden Path templates.
*   **Self-Service Cloud Provisioning:** Implemented Crossplane control planes on EKS, allowing developers to request PostgreSQL databases without manual infrastructure interventions.
*   **Automated Audit Trail:** Enabled Backstage to automatically register and close ServiceNow Standard Change tickets for every self-service provisioning action.
*   **200+ Services Centralized:** Created a unified Software Catalog tracking owners, Swagger API endpoints, and real-time deployment status across the enterprise.

---

## 🏗️ The Architecture Landscape

To enable developer self-service while enforcing strict financial and security policies, we built the following architecture:

```
                            INTERNAL DEVELOPER PORTAL LOGICAL FLOW
                            ══════════════════════════════════════
  
           [ USAA Developer ] ──► [ Backstage Developer Portal (EKS) ]
                                                │
                          ┌─────────────────────┼─────────────────────┐
                          ▼                     ▼                     ▼
                 [ Scaffolding Engine ]  [ Software Catalog ]  [ Cloud Provisioner ]
                          │                     │                     │
      ┌───────────────────┼───────────────────┐ │                     ▼
      ▼                   ▼                   ▼ │             [ Crossplane CRD ]
 [ GitHub Repo ]   [ CI Pipeline ]   [ ArgoCD App ]│                     │
 (Secure Skeleton) (GitHub Actions)  (Auto-Deploy)│                     ▼
                                                │             [ AWS RDS database ]
                                                │                     │
                                                ▼                     ▼
                                      [ ServiceNow API ] ──► [ Standard Change CHG ]
```

### Key Components:
*   **Spotify Backstage:** An open-source Developer Portal hosting the software catalog, API documents, and Golden Path templates.
*   **Backstage Scaffolder:** The template engine that takes developer inputs, copies golden skeleton code, replaces variable placehoders, and creates the GitHub repository.
*   **Crossplane:** An EKS-native Kubernetes controller that provisions cloud resources (like AWS RDS databases) directly using Kubernetes Custom Resources (CRDs).
*   **ServiceNow Integration API:** Custom node script executing REST calls to ServiceNow to automate the ticketing lifecycle.

---

## ⚠️ The Problem: "Ticket Ops" & Configuration Drift

Before USAA implemented Backstage, microservice onboarding was heavily bottlenecked:

1.  **High Provisioning Wait Times (Ticket Ops):** Developers wanting to start a project had to open a Jira ticket for a Git repo, another ticket for a Jenkins pipeline, and another ticket for an RDS database. DevOps teams had to manually fulfill these tickets, causing wait times of 5 to 7 days.
2.  **Configuration Drift:** Application code lacked standard structure. Developers copy-pasted Dockerfiles and Helm charts from old projects, propagating deprecated configurations, outdated security patches, and incorrect resource limits.
3.  **The "Who Owns This?" Problem:** During production outages, identifying the on-call engineer, owner team, or API documentation for a dependent microservice was difficult because metadata was scattered across wikis, readmes, and spreadsheets.

---

## 🔄 End-to-End Automated Golden Path Flow

Here is exactly how a developer provisions resources in under 3 minutes:

### 1. Requesting the Service
*   The developer logs into Backstage, selects the **"Create Spring Boot Microservice with Database"** template, and enters:
    - Service Name: `claims-payout-api`
    - Owner Team: `Claims-Squad-Alpha`
    - DB Size: `db.t3.medium` (with 20GB storage)

### 2. Repo Scaffolding
*   The Backstage Scaffolder engine fetches the approved USAA Golden Template from GitHub.
*   It generates a new GitHub Enterprise repository (`usaa-claims/claims-payout-api`).
*   It populates the repository with:
    - An audited Spring Boot template (including security scanner dependencies).
    - Pre-configured GitHub Actions pipelines.
    - Helm charts matching cluster ingress configurations.
    - A standard `catalog-info.yaml` registry file indicating ownership.

### 3. Cloud Database Provisioning
*   Backstage writes a Crossplane `RDSInstance` manifest and commits it to the repository.
*   ArgoCD detects the manifest and synchronizes it to EKS.
*   The Crossplane AWS controller intercepts the resource and calls the AWS RDS API, provisioning the database securely in USAA's private database subnets.

### 4. ServiceNow Auto-Approval
*   The Scaffolder executes an API call to ServiceNow.
*   It creates a pre-approved Standard Change request (`CHG`) indicating that a standard golden project was created.
*   It logs the transaction ID, owner team, and database ARN.
*   It alerts the `#platform-provisioning-logs` channel in Microsoft Teams with links to the new repository and the change ticket.

---

## ☁️ AWS & Open-Source Tools Used

| Tool | Role in This Project | Why We Chose It |
| :--- | :--- | :--- |
| **Spotify Backstage** | Core Internal Developer Portal framework | Highly customizable, plug-in architecture, large enterprise community |
| **Crossplane** | Kubernetes-native Infrastructure Provider | Allows infrastructure provisioning using declarative Kubernetes manifests |
| **GitHub Enterprise** | Version control & repository hosting | Secure repository generation via API endpoints |
| **ArgoCD** | GitOps Deployment Engine | Natively syncs Crossplane manifests to EKS clusters |
| **AWS RDS (PostgreSQL)** | Managed database instance | Secure, automatically backed up database engine |
| **Amazon EKS** | Managed Kubernetes hosting the Backstage UI | Uniform platform for both the portal and Crossplane controllers |

---

## 🛠️ My Contribution as a DevOps Engineer

### What I Built

| Deliverable | Description |
| :--- | :--- |
| **Backstage Software Templates** | Authored the template declarations ([backstage-template.yaml](file:///Users/aravind/Desktop/Devops/DevOps-proj/DevOps-use-cases/internal_developer_platform/kubernetes/backstage-template.yaml)) defining UI form inputs and scaffolding actions |
| **Crossplane Declarations** | Designed the reusable Crossplane custom database manifest ([crossplane-db.yaml](file:///Users/aravind/Desktop/Devops/DevOps-proj/DevOps-use-cases/internal_developer_platform/kubernetes/crossplane-db.yaml)) |
| **Portal Deployment Charts** | Authored Helm charts deploying Spotify Backstage and the EKS ingress configurations |
| **ITSM ServiceNow Script** | Coded the Backstage custom software template action calling the ServiceNow REST API |
| **Teams chat webhook** | Configured Backstage notification publisher logging events |

### What I Did NOT Build (Boundaries)

| Area | Who Built It | My Role |
| :--- | :--- | :--- |
| **Spring Boot Base Application Code** | App Tech Leads | I packaged their code skeleton into the template folder |
| **ServiceNow core workflow templates** | ITSM Team | I invoked their pre-approved table routes |
| **AWS database security credentials** | Security Team | I configured Crossplane to query their KMS key references |

---

## 🔒 DevOps Engineer Boundaries

### ✅ My Lane (I Own This)

```text
Portal Architecture Setup (Backstage Helm) ─── I manage the portal deployment and plugins
Self-Service Scaffolding Templates ────────── I write Backstage template manifests and golden paths
EKS Crossplane Provider Configurations ────── I configure IAM roles and providers for Crossplane
ServiceNow REST Integration Scripts ───────── I write the API connector scripts in Backstage templates
```

### 🚫 Not My Lane (I Collaborate But Don't Own)

```text
Application Golden Code Skeletons ─────────── Development Tech Leads design base framework code
AWS Base Database Cluster Configurations ──── Database Administrators define DB sizing limits
ServiceNow Table API Design ───────────────── ITSM Team manages database schemas for change tickets
```

---

## 📅 Project Duration & Timeline (10–12 Weeks)

### Phase 1: Assessment & Framework Design (Weeks 1–2)
* Gather developer pain points and catalog templates required by product groups.
* Research Backstage architecture and install base charts in non-production EKS clusters.
* Request network security rules to allow EKS egress calls to GitHub Enterprise and ServiceNow.

### Phase 2: Software Catalog & Plugins (Weeks 3–5)
* Configure Backstage Software Catalog integrating with GitHub Enterprise via automated discovery.
* Deploy Backstage plugins for ArgoCD, GitHub Actions, and TechDocs.
* Import existing 50+ microservices to populate the portal registry.

### Phase 3: Golden Path Scaffolding & Database Provisioning (Weeks 6–8)
* Authored Backstage Software Templates for Spring Boot and React projects.
* Install Crossplane on EKS and register AWS Providers with KMS encryption.
* Create self-service Crossplane custom manifests for RDS database creation.

### Phase 4: ServiceNow & Alerting Integration (Weeks 9–10)
* Program custom scaffolding actions in Backstage to call ServiceNow Table API.
* Implement MS Teams Webhooks logging pipeline notifications.
* Conduct validation sessions with test squads bootstrapping mock applications.

### Phase 5: Go-Live & Developer Adoption (Weeks 11–12)
* Deploy Backstage and Crossplane policies to production environments.
* Train developer teams on Golden Path provisioning.
* Decommission manual Jira ticketing pipelines for project creation.

---

## 🔍 Step-by-Step Technical Deep-Dive

### Step 1: Backstage Software Template (Scaffolder)
We define the UI form steps and the execution tasks:

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: spring-boot-rds-template
  title: Spring Boot Microservice with RDS
  description: Scaffolds a Spring Boot application with a self-service AWS PostgreSQL database.
spec:
  owner: cloud-platform-team
  type: service

  parameters:
    - title: Microservice Metadata
      required:
        - component_id
        - owner
      properties:
        component_id:
          title: Service Name
          type: string
          description: Unique name of the microservice (e.g. claims-payout-api)
        owner:
          title: Owner Team
          type: string
          description: USAA Team responsible for this service

    - title: Database Parameters
      required:
        - db_size
      properties:
        db_size:
          title: Database Instance Class
          type: string
          default: db.t3.medium
          enum:
            - db.t3.medium
            - db.t3.large

  steps:
    - id: template
      name: Scaffolding Skeleton
      action: fetch:template
      input:
        url: ./skeleton
        values:
          componentId: ${{ parameters.component_id }}
          owner: ${{ parameters.owner }}
          dbSize: ${{ parameters.db_size }}

    - id: publish
      name: Publish to GitHub
      action: publish:github
      input:
        allowedHosts: ['github.com']
        description: Scaffolder-generated repository for ${{ parameters.component_id }}
        repoUrl: github.com?owner=usaa-claims&repo=${{ parameters.component_id }}

    - id: register-servicenow
      name: Log ServiceNow Change Request
      action: http:request
      input:
        url: https://usaa.service-now.com/api/now/table/change_request
        method: POST
        headers:
          Content-Type: application/json
        body:
          short_description: "Automated Provisioning: ${{ parameters.component_id }}"
          description: "Developer portal self-service creation. Rep: github.com/usaa-claims/${{ parameters.component_id }}. DB size: ${{ parameters.db_size }}."
          type: "standard"
```

### Step 2: Crossplane AWS Database Custom Resource
When ArgoCD syncs the generated database configuration file, Crossplane provisions the resource:

```yaml
apiVersion: database.aws.crossplane.io/v1beta1
kind: RDSInstance
metadata:
  name: claims-payout-db
  namespace: banking
spec:
  forProvider:
    region: us-east-1
    dbInstanceClass: db.t3.medium
    engine: postgres
    engineVersion: "15.4"
    masterUsername: postgres
    allocatedStorage: 20
    dbSubnetGroupName: usaa-private-db-subnet-group
    vpcSecurityGroupIds:
      - sg-0123456789abcdef0
    skipFinalSnapshot: true
  writeConnectionSecretToRef:
    namespace: banking
    name: claims-payout-db-conn
```

---

## 🚨 ITSM Incident Management Flow

To maintain security compliance, the portal logs standard changes.

### ServiceNow Ticket Mockup
Every repository and database created via the platform registers an audit log:

```
CHANGE REQUEST: CHG-0089721
--------------------------------------------------------------------------------
Short Description: Automated Golden Path Scaffolding: claims-payout-api
Assignment Group:  Platform-DevOps-Team
Status:            Closed - Complete
Priority:          4 - Low (Standard, Pre-Approved Change)
Description:       
USAA Developer Portal (Backstage) triggered automated provisioning of microservice
repository: claims-payout-api. Software Template: Spring Boot RDS template.
Developer Team: Claims-Squad-Alpha. Database Class: db.t3.medium.

Resolution:
Repository generated successfully. Crossplane applied database config in us-east-1.
RDS Instance successfully provisioned. Closed automatically.
--------------------------------------------------------------------------------
```

---

## 💬 Interview Preparation (Q&A)

### Q1: What is an Internal Developer Platform (IDP), and why did USAA need one?
**Answer:** An Internal Developer Platform is a self-service portal (like Spotify Backstage) that packages infrastructure tools, APIs, and templates into Golden Paths for developers. Before the IDP, developers faced "ticket ops," waiting days for Git repositories, database setups, and CI/CD configurations. By automating these tasks via Backstage templates and EKS Crossplane control planes, we reduced the provisioning time from 5 days to 3 minutes, while ensuring that all projects conform to USAA security and tagging compliance standards.

### Q2: Why did you use Crossplane instead of Terraform for the self-service DB provisioning?
**Answer:** While Terraform is excellent for static infrastructure setup, it requires a pipeline runner to execute planning and applying processes. Developers would need git commit approvals to trigger these. Crossplane runs inside the Kubernetes cluster as an active control plane. It exposes AWS resources as Kubernetes Custom Resources (CRDs). When Backstage templates write a Crossplane database manifest, ArgoCD syncs it, and Crossplane provisions it. If the DB is modified outside of Kubernetes (drift), Crossplane detects it and reconciles it back automatically, providing self-healing infrastructure.

### Q3: How did you handle credential security for self-service database access?
**Answer:** Crossplane allows writing the generated database host, port, and credentials directly to a Kubernetes secret using the `writeConnectionSecretToRef` parameter. We configure this secret to be saved inside the respective microservice namespace. The pod securityContext and IAM Roles for Service Accounts (IRSA) restrict access so only that microservice's containers can read the secret. We also integrate AWS Secrets Manager to rotate the passwords automatically every 30 days.
