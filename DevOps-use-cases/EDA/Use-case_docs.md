# 🏗️ USAA Enterprise Use Case: Event-Driven Insurance Claims Pipeline

This document provides a detailed, end-to-end technical explanation of how USAA processes insurance claims using an Event-Driven Architecture (EDA) on AWS, including team structure, responsibilities, and DevOps engineer boundaries.

---

## 📋 Project Summary

| Field | Details |
| :--- | :--- |
| **Project Name** | Event-Driven Claims Processing Pipeline |
| **Company** | USAA (United Services Automobile Association) |
| **Industry** | Financial Services / Insurance |
| **My Role** | DevOps Engineer — Cloud Platform Team |
| **Reporting To** | DevOps Engineering Manager (Platform Infrastructure) |
| **Project Duration** | ~10–12 weeks (2.5 to 3 months) |
| **Infrastructure** | AWS (Serverless — EventBridge, Lambda, SQS, SNS, DynamoDB, Step Functions) |
| **Communication** | Microsoft Teams |
| **Ticketing** | Jira (Sprint Tracking) + ServiceNow (Change Management) |

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
*   **Daily Standups**: Scrum Master runs the daily standup. I report blockers to the Engineering Manager.
*   **Sprint Reviews**: I demo infrastructure changes to the Director of Platform Engineering and cross-functional stakeholders every 2 weeks.
*   **Incident Escalation**: During P1/P2 incidents, I report directly to the Incident Commander (typically the on-call Sr. DevOps Engineer or the Engineering Manager).

---

## 👥 Cross-Collaboration Teams & Team Members

### Core Project Team (8–10 People)

| Role | Name (Example) | Responsibility | Interaction Frequency |
| :--- | :--- | :--- | :--- |
| **DevOps Engineer (Me)** | Aravind K. | Terraform IaC, CI/CD pipelines, Lambda deployment, monitoring | Daily |
| **Sr. DevOps Engineer** | Michael R. | Architecture review, production access approval, mentorship | Daily |
| **Jr. DevOps Engineer** | Sarah L. | Assist with monitoring dashboards, Terraform module testing | Daily |
| **Backend Engineer (Claims)** | David P. | Writes claims_processor and fraud_detector Lambda business logic | 3–4x/week |
| **Backend Engineer (Notifications)** | Priya S. | Writes notification_sender Lambda and SNS message templates | 2–3x/week |
| **Data Scientist (Fraud ML)** | James W. | Trains and deploys the SageMaker fraud scoring model | Weekly |
| **QA/SDET Engineer** | Maria G. | Integration testing, load testing, regression test suites | 2–3x/week |
| **Scrum Master** | Kevin T. | Sprint planning, backlog grooming, standup facilitation | Daily |
| **Product Owner** | Lisa M. | Defines acceptance criteria, prioritizes features, stakeholder liaison | Weekly |

### Cross-Functional Teams I Collaborate With

| Team | What They Own | How I Interact |
| :--- | :--- | :--- |
| **Cloud Network Security** | VPC design, security groups, NACLs, firewall rules | Submit ServiceNow requests for port openings between services |
| **PKI / InfoSec** | Certificate policies, Venafi configurations, encryption standards | Integrate their Venafi APIs into Cert-Manager |
| **ITSM / IT Operations** | ServiceNow templates, Change Advisory Board (CAB) process | Use their API to auto-create change tickets |
| **Data Engineering** | Kinesis streams, S3 data lake, Redshift pipelines | Hand off analytics events to their Kinesis ingestion endpoint |
| **DBA Team** | DynamoDB schema design, capacity planning, backup strategy | Implement their schema in Terraform, configure auto-scaling |
| **Compliance / GRC** | SOX, PCI-DSS, FFIEC regulatory requirements | Ensure infrastructure meets their audit requirements (encryption, logging) |
| **SRE / On-Call** | Production monitoring, incident management, runbooks | Collaborate on alerting thresholds and escalation procedures |

---

## 🏗️ Architecture Explanation

### What is Event-Driven Architecture (EDA)?
Instead of services directly calling each other (request-response), services **emit events** when something happens, and other services **react** to those events asynchronously. The services are completely **decoupled** — the producer doesn't know or care who consumes the event.

### End-to-End Claims Flow

```text
[ USAA Member Files Claim via Mobile App ]
                    │
                    ▼ (ClaimFiled Event)
   ┌────────────────────────────────────────────┐
   │         Amazon EventBridge                  │
   │         (usaa-claims-event-bus)             │
   │                                            │
   │  Rule 1: ClaimFiled ──────► Claims Processor│
   │  Rule 2: ClaimValidated ──► Fraud Detector  │
   │  Rule 3: Status Change ──► Notifications    │
   │  Rule 4: ALL Events ─────► Analytics        │
   └────────────────────────────────────────────┘
                    │
   ┌────────────────┼───────────────┬──────────────────┐
   ▼                ▼               ▼                  ▼
[ Claims          [ Fraud          [ Notification     [ Analytics
  Processor ]       Detector ]       Sender ]           Ingester ]
   │                │               │                  │
   ▼                ▼               ▼                  ▼
 DynamoDB        EventBridge      SNS + Teams        Data Lake
 (persist         (route by        (email, SMS,       (Kinesis →
  claim)           risk score)      push, webhook)     S3 → Redshift)
```

### Step Functions — Claim Approval Workflow

```text
                    ┌──────────────┐
                    │ ValidateClaim │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │  FraudCheck   │
                    └──────┬───────┘
                           │
                ┌──────────▼──────────┐
                │  EvaluateFraudScore  │
                └──┬───────┬───────┬──┘
                   │       │       │
          Score<0.3│  0.3-0.7│   >0.7│
                   ▼       ▼       ▼
            ┌──────────┐ ┌──────┐ ┌─────────┐
            │Auto-     │ │Flag  │ │Escalate │
            │Approve   │ │Review│ │to SIU   │
            └────┬─────┘ └──┬───┘ └────┬────┘
                 │          │          │
                 └──────────┼──────────┘
                            ▼
                   ┌────────────────┐
                   │RecordAnalytics │
                   └────────────────┘
```

---

## ☁️ AWS Services Used

| AWS Service | Role in This Project | Why We Chose It |
| :--- | :--- | :--- |
| **Amazon EventBridge** | Central event bus — routes claim events to consumers based on rules | Fully managed, native AWS integration, content-based filtering |
| **AWS Lambda** | Serverless compute — runs the 4 consumer functions | Pay-per-invocation, no servers to manage, auto-scales to zero |
| **Amazon SQS** | Message queue with DLQ — buffers events for each consumer | Decouples producers from consumers, retries failed messages |
| **Amazon SNS** | Fan-out notifications — email, SMS, push to members | Multi-channel delivery, native Lambda/SQS integration |
| **Amazon DynamoDB** | NoSQL data store — persists claim records with status tracking | Single-digit millisecond latency, on-demand scaling, point-in-time recovery |
| **AWS Step Functions** | Workflow orchestration — multi-step approval with branching logic | Visual workflow designer, built-in error handling, audit trail |
| **Amazon SageMaker** | ML model hosting — fraud risk scoring inference endpoint | Managed ML inference, A/B testing, model monitoring |
| **AWS Secrets Manager** | Stores API credentials for ServiceNow, Jira, Teams | Automatic rotation, fine-grained IAM access control |
| **Amazon CloudWatch** | Logging, metrics, dashboards, alarms | Centralized observability, Lambda auto-integration |
| **AWS IAM** | Identity and access — least-privilege roles for each Lambda | Enforces security boundaries between services |

---

## 🛠️ My Contribution as a DevOps Engineer

### What I Built

| Deliverable | Description |
| :--- | :--- |
| **Terraform Modules** | Authored all 8 Terraform configurations (EventBridge, SQS, SNS, DynamoDB, Lambda, Step Functions, IAM, providers) |
| **CI/CD Pipeline** | Designed and built the GitHub Actions workflow with Terraform validation, Python compilation, and security scanning |
| **Lambda Deployment** | Configured the Lambda packaging (zip archives), environment variables, IAM roles, and EventBridge trigger permissions |
| **Monitoring & Alerting** | Set up CloudWatch log groups, metric alarms for Lambda errors/throttles, and DynamoDB read/write capacity alerts |
| **ITSM Integration** | Wired the Lambda notification handler to create ServiceNow Change Tickets and Jira Incident tickets automatically |
| **Teams ChatOps** | Configured the Microsoft Teams incoming webhook integration for real-time `#claims-ops` channel alerts |
| **Dead-Letter Queue Strategy** | Designed the DLQ architecture (3 retry attempts → DLQ → CloudWatch alarm → PagerDuty/Teams alert) |
| **Documentation** | Created `README.md`, architecture diagrams, and runbooks for the on-call team |

### What I Did NOT Build (Boundaries)

| Area | Who Built It | My Role |
| :--- | :--- | :--- |
| **Claims validation business logic** (inside `claims_processor`) | Backend Engineer (David P.) | I deployed his code via Lambda, set up the IAM role, and configured the DynamoDB environment variable |
| **Fraud scoring ML model** | Data Scientist (James W.) | I deployed the SageMaker endpoint via Terraform and configured the Lambda to call the inference API |
| **SNS message templates** (email copy, SMS wording) | Backend Engineer (Priya S.) + Product Owner | I configured the SNS topics and subscriptions in Terraform |
| **DynamoDB table schema** (partition key, sort key, GSI design) | Backend Engineer (David P.) + DBA Team | I implemented their schema in `dynamodb.tf` |
| **VPC / Network architecture** | Cloud Network Security team | I submitted ServiceNow requests for security group rules |
| **Compliance requirements** (encryption, audit logging) | GRC / Compliance team | I implemented their requirements (DynamoDB encryption at rest, CloudWatch log retention) |

---

## 🔒 DevOps Engineer Boundaries

### ✅ My Lane (I Own This)

```text
Infrastructure as Code (Terraform)  ──────────── I write and maintain it
CI/CD Pipelines (GitHub Actions)     ──────────── I design and troubleshoot it
Lambda Packaging & Deployment        ──────────── I package, deploy, and monitor it
IAM Roles & Security Policies        ──────────── I define least-privilege access
Monitoring & Alerting (CloudWatch)   ──────────── I set up dashboards and alarms
ITSM Integration (ServiceNow/Jira)   ──────────── I build the API connections
Secret Management (Secrets Manager)  ──────────── I configure and rotate credentials
Incident Response (Infrastructure)   ──────────── I'm on-call for infra failures
```

### 🚫 Not My Lane (I Collaborate But Don't Own)

```text
Application Business Logic           ──────────── Developers write it
ML Model Training                    ──────────── Data Science team trains it
Database Schema Design               ──────────── Backend + DBA team designs it
Network/Firewall Rules               ──────────── Network Security team manages it
Compliance Policy Definition         ──────────── GRC team defines requirements
ServiceNow Template Design           ──────────── ITSM team owns the templates
Domain/DNS Ownership                 ──────────── InfoSec/Domain Admin approves
```

---

## 📅 Project Duration & Timeline (10–12 Weeks)

### Phase 1: Discovery & Design (Weeks 1–2)
*   Meet with the Architecture team to finalize the event-driven design pattern
*   Define the EventBridge event schemas with Backend Engineers
*   Submit ServiceNow requests for AWS account access, VPC security groups, and Secrets Manager permissions
*   Create Jira Epic and User Stories for the sprint backlog

### Phase 2: Core Infrastructure Build (Weeks 3–5)
*   Author Terraform modules for EventBridge, SQS, SNS, DynamoDB
*   Set up the GitHub Actions CI/CD pipeline with Terraform validation
*   Deploy the initial Lambda functions with stub/mock handlers
*   Configure IAM roles with least-privilege policies

### Phase 3: Lambda Integration & Testing (Weeks 6–8)
*   Backend Engineers deliver the claims_processor and fraud_detector Lambda code
*   Data Science team deploys the SageMaker fraud model endpoint
*   I package and deploy all 4 Lambda functions via Terraform
*   QA runs integration tests against the dev environment
*   Set up CloudWatch dashboards and alerting thresholds

### Phase 4: ITSM & ChatOps Integration (Weeks 9–10)
*   Connect Lambda notification handler to ServiceNow API (auto-create CHG tickets)
*   Connect to Jira API (auto-create Incident tickets on failure)
*   Configure Microsoft Teams webhooks for `#claims-ops` channel
*   Run end-to-end dry runs simulating claim submissions and failures

### Phase 5: Production Go-Live & Canary Rollout (Weeks 11–12)
*   Submit production Change Request in ServiceNow for CAB approval
*   Deploy to production using blue/green strategy
*   Start with **1 claim type** (auto_collision) as a canary
*   Monitor for 1–2 weeks, then onboard remaining claim types (home, property, life)
*   Hand off runbooks to the SRE/On-Call team

---

## 💬 Interview Q&A

### Q1: "What was this project about?"
> *"We built an event-driven, serverless insurance claims processing pipeline on AWS. When a USAA member files a claim through the mobile app, it publishes a ClaimFiled event to Amazon EventBridge. Four independent Lambda consumers react to the event — one validates and persists the claim, one runs fraud detection, one sends notifications to the member via SNS and alerts our ops team via Teams, and one streams the data to our analytics pipeline. We used Step Functions to orchestrate the multi-step approval workflow with branching logic based on the fraud risk score."*

### Q2: "What was your role specifically?"
> *"I was the DevOps engineer responsible for the entire infrastructure lifecycle. I authored all the Terraform modules — EventBridge, SQS with dead-letter queues, SNS topics, DynamoDB tables, Lambda functions, Step Functions, and IAM roles. I built the CI/CD pipeline in GitHub Actions and set up the monitoring stack in CloudWatch. I also owned the ITSM integration layer — connecting our Lambda functions to ServiceNow for automated change management and Jira for incident tracking. The business logic inside the Lambda functions was written by the backend engineering team."*

### Q3: "How did you handle failures?"
> *"We designed a multi-layer resilience strategy. Each SQS queue has a dead-letter queue configured with a max receive count of 3. If a message fails 3 times, it lands in the DLQ, which triggers a CloudWatch alarm that pages the on-call engineer via PagerDuty and sends an alert to our Teams channel. For the Step Functions workflow, we have Catch blocks on every state that route errors to a NotifyFailure state, which sends a notification to the member and creates a Jira incident. We also have EventBridge replay capability — if an entire consumer goes down, we can replay missed events from the archive."*

### Q4: "How long did this project take?"
> *"About 10 to 12 weeks end to end. The first 2 weeks were design and planning — aligning with the architecture team on event schemas and submitting access requests. Weeks 3 through 8 were the core build — Terraform, Lambda deployment, and integration testing. Weeks 9 and 10 were the ITSM integration with ServiceNow and Teams. The final 2 weeks were production deployment using a canary approach — we started with auto collision claims only, monitored for a week, and then gradually onboarded the remaining claim types."*

### Q5: "Who did you work with?"
> *"I worked most closely with two backend engineers who wrote the Lambda business logic, a data scientist who trained the fraud model, and our QA engineer for integration testing. I also collaborated with the Cloud Network Security team for VPC access, the ITSM team for ServiceNow API credentials, and the GRC team to ensure our infrastructure met compliance requirements like encryption at rest and audit logging. I reported to the DevOps Engineering Manager and presented sprint demos to the Director of Platform Engineering."*
