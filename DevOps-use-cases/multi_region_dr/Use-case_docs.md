📊 USAA Enterprise Use Case: Multi-Region Active-Passive DR & Routing (Route 53 ARC)

This document provides a detailed, end-to-end technical explanation of how USAA implemented an automated, multi-region Active-Passive Disaster Recovery (DR) and global traffic routing framework for banking core microservices, achieving an RTO under 2 minutes and RPO under 1 second.

Use this reference to prepare for interviews and explain this architecture step-by-step.

---

## 📋 Project Summary

| Field | Details |
| :--- | :--- |
| **Project Name** | Multi-Region Active-Passive DR & Traffic Management |
| **Company** | USAA (United Services Automobile Association) |
| **Industry** | Financial Services / Insurance |
| **My Role** | DevOps Platform Engineer — Delivery Automation Enablement Team |
| **Reporting To** | Lead DevOps Infrastructure Engineer (Platform Infrastructure Org) |
| **Project Duration** | ~10–12 weeks (2.5 to 3 months) |
| **Infrastructure** | AWS Route 53 Application Recovery Controller (ARC), EKS Multi-Region (us-east-1 & us-west-2), DynamoDB Global Tables, Route 53, CloudWatch, Lambda, ArgoCD |
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
*   **Daily Standups**: Scrum Master runs the daily standup. I report progress, deployment statuses, and blockers to the Lead DevOps Infrastructure Engineer.
*   **Sprint Reviews**: I demo DNS failover test executions and global routing dashboards to the Engineering Manager (Platform Infrastructure Org) and the Disaster Recovery Governance team every 2 weeks.

---

## 👥 Cross-Collaboration Teams & Team Members

### Core Project Team (8 People)

| Role | Name (Example) | Responsibility | Interaction Frequency |
| :--- | :--- | :--- | :--- |
| **DevOps Engineer (Me)** | Aravind K. | Terraform IaC (ARC and Route 53), ArgoCD multi-cluster pipelines, failover Lambda scripts | Daily |
| **Sr. DevOps Engineer** | Michael R. | Cross-region network layout approval, Route 53 Routing Control architecture review, failover verification | Daily |
| **Jr. DevOps Engineer** | Sarah L. | CloudWatch synthetic canary alerts, Route 53 health check scripts, Terraform code formatting | Daily |
| **Database Architect** | David P. | DynamoDB Global Tables partition layout, read/write throughput capacity tuning, replication lag review | 3–4x/week |
| **DR Governance Lead** | Sarah L. | Verifying FFIEC regulatory compliance, definition of RTO/RPO validation steps | Weekly |
| **QA Lead** | Maria G. | Executing Chaos Engineering experiments (injecting region failure), measuring database replication recovery | 2–3x/week |
| **Scrum Master** | Kevin T. | Sprint planning, standup facilitation, blocker removal | Daily |
| **Product Owner** | Lisa M. | Aligning microservices onboarding requirements, release schedules, stakeholder reporting | Weekly |

---

## 🏆 Achievements

*   **Sub-2 Minute RTO:** Successfully automated EKS global routing failover, bypassing standard DNS TTL propagation delays.
*   **Near-Zero RPO:** Utilized DynamoDB Global Tables to ensure transactional data is replicated cross-region within milliseconds, avoiding financial data loss.
*   **99.999% Availability Plan:** Met strict federal (FFIEC) regulatory compliance for bank resilience by configuring independent routing control panels.
*   **Automated ITSM Audit Trail:** Configured automated creation of ServiceNow Emergency Change tickets on failover execution.
*   **Multi-Cluster GitOps Sync:** Managed continuous deployment parity across AWS regions (`us-east-1` and `us-west-2`) using ArgoCD ApplicationSets.

---

## 🏗️ The Architecture Landscape

To achieve robust DR, we established a multi-region active-passive topology:

```
                            GLOBAL TRAFFIC INGRESS & DISASTER RECOVERY
                            ═════════════════════════════════════════
  
                                  [ USAA Banking Clients ]
                                             │
                                             ▼
                               [ AWS Route 53 Latency DNS ]
                                             │
                       ┌─────────────────────┴─────────────────────┐
                       │                                           │
                       ▼ (Primary Path - Routing Switch: ON)       ▼ (DR Path - Routing Switch: OFF)
             [ Route 53 ARC Control ]                    [ Route 53 ARC Control ]
                       │                                           │
                       ▼                                           ▼
             [ ALB us-east-1 (Primary) ]                 [ ALB us-west-2 (DR) ]
                       │                                           │
                       ▼                                           ▼
            [ EKS Cluster (us-east-1) ]                 [ EKS Cluster (us-west-2) ]
                       │                                           │
                       └───────────────────┬───────────────────────┘
                                           │
                                           ▼
                         [ Amazon DynamoDB Global Tables ]
                          (Active-Active Multi-Region Replication)
```

### Key Components:
*   **AWS Route 53 Application Recovery Controller (ARC):** A high-availability control plane providing routing controls (switches) that survive single-region AWS outages.
*   **Multi-Cluster EKS:** Twin Kubernetes clusters deployed in `us-east-1` (Primary) and `us-west-2` (DR) running identical software stacks synchronized by ArgoCD.
*   **DynamoDB Global Tables:** Multi-region, active-active DynamoDB databases that automatically replicate write transactions cross-region within 1 second.
*   **ArgoCD GitOps:** Centralized git-based deployment engine ensuring that both EKS clusters maintain 100% configuration parity.
*   **Failover Lambda Orchestrator:** Python-based automation executing failover runs, validating EKS health, toggling ARC routing controls, and calling ServiceNow APIs.

---

## ⚠️ The Problem: Slow and Risky Regional Failovers

Prior to implementing AWS Route 53 ARC, USAA's banking core applications were vulnerable to regional outages:

1.  **DNS TTL Latency (The Cache Problem):** Traditional failovers relied on changing DNS records in Route 53. However, ISP DNS servers and client browsers cache DNS records based on the TTL (Time to Live). Even with a low TTL (60s), client traffic would continue hitting the dead region for 15–30 minutes, causing transaction failures.
2.  **No Single Source of Truth for Routing:** During an outage, operators had to manually edit Route 53 records. This manual change was slow, error-prone, and bypassed official ITSM approval processes.
3.  **Data Inconsistency (Split-Brain Risk):** If traffic routing was switched before databases were fully synchronized, data could become corrupted or split across regions. We needed a reliable routing state store that is totally decoupled from standard DNS propagation.

---

## 🔄 End-to-End Automated Failover Flow

Here is exactly how regional failover is executed dynamically:

### 1. Route 53 ARC Routing Control Setup
*   Route 53 ARC uses a global redundant control plane distributed across five AWS regions. This guarantees that we can toggle routing switches even if the region containing our primary EKS cluster goes completely offline.
*   We define **Routing Controls** (virtual switches) that gate Route 53 DNS routing queries. Route 53 ARC resolves DNS queries based on the state (Active/Inactive) of these controls.

### 2. Active-Passive Flow
*   Under normal circumstances, the `us-east-1` control is set to `ON` (Active), and the `us-west-2` control is set to `OFF` (Inactive). All user requests are routed to `us-east-1`.
*   ArgoCD continuously deploys matching manifests to both clusters, keeping the standby EKS cluster hot and ready to accept traffic.

### 3. Failover Execution
*   When a critical incident occurs (e.g., severe region degradation in `us-east-1`), CloudWatch alarms trigger the Failover Lambda.
*   The Lambda validates health on the DR cluster (`us-west-2`).
*   It updates the Route 53 ARC state: `us-east-1` is toggled to `OFF`, and `us-west-2` is toggled to `ON`.
*   Route 53 ARC applies this change in milliseconds globally, routing new TCP connections to the DR region without waiting for DNS records to propagate.

---

## ☁️ AWS Services Used

| AWS Service | Role in This Project | Why We Chose It |
| :--- | :--- | :--- |
| **AWS Route 53 ARC** | Manages routing controls and cluster readiness checks | Distributed across 5 regions, highly resilient, sub-second routing updates |
| **Amazon EKS** | Managed Kubernetes hosting core microservices in both regions | Ensures uniform runtime environment across AWS regions |
| **DynamoDB Global Tables** | Fully managed database with cross-region replication | Provides active-active replication, preventing data loss during failover |
| **AWS Route 53** | Global Domain Name System (DNS) routing | Native integration with ARC routing controls for global traffic steering |
| **AWS Lambda** | Python script executing ARC API calls and ServiceNow requests | Serverless, highly available, executes rapidly without infrastructure overhead |
| **Amazon EventBridge** | Event router triggering failover automation | Direct mapping from CloudWatch health alarm triggers to Lambda |
| **Amazon CloudWatch** | Aggregates regional infrastructure metrics and synthetics | Monitors health checks and triggers automated alarms |
| **AWS Secrets Manager** | Securely stores API credentials for ServiceNow and Jira | Enforces compliance, allows programmatic access for Lambda |

---

## 🛠️ My Contribution as a DevOps Engineer

### What I Built

| Deliverable | Description |
| :--- | :--- |
| **Terraform Modules** | Authored the infrastructure declarations ([arc.tf](file:///Users/aravind/Desktop/Devops/DevOps-proj/DevOps-use-cases/multi_region_dr/terraform/arc.tf), [dynamodb.tf](file:///Users/aravind/Desktop/Devops/DevOps-proj/DevOps-use-cases/multi_region_dr/terraform/dynamodb.tf)) |
| **GitOps Multi-Cluster Setup** | Configured ArgoCD ApplicationSets targeting both regional Kubernetes API servers |
| **Failover Lambda Client** | Developed python script utilizing `boto3` to toggle ARC routing controls and query readiness checks |
| **Observability Stack** | Set up Route 53 health checks and configured CloudWatch alarms routing to EventBridge |
| **ServiceNow ITSM Connector** | Programmed API call in failover script to create ServiceNow Emergency Change requests |
| **Teams Notification payload** | Formed payload for Teams incoming webhook to alert engineers of regional failover states |

### What I Did NOT Build (Boundaries)

| Area | Who Built It | My Role |
| :--- | :--- | :--- |
| **Core application code** | App Engineers | I synchronized their deployments across regions via ArgoCD |
| **DynamoDB schema structure** | Database Architect | I declared the resource and configured global tables in Terraform |
| **ITSM Emergency workflows** | ITSM Operations Team | I consumed their API endpoint to log changes during failovers |
| **VPC routing tables & peering** | Cloud Network Security | I imported their pre-configured VPC subnets for EKS deployment |

---

## 🔒 DevOps Engineer Boundaries

### ✅ My Lane (I Own This)

```text
Infrastructure as Code (Terraform) ─────────── I write, maintain, and validate global ARC/DNS layouts
Multi-Cluster CD GitOps Pipelines  ─────────── I configure ArgoCD sync processes and applications
Failover Orchestrator Lambda Scripts ───────── I write python boto3 code that handles routing switches
Observability & Health Monitoring   ────────── I configure CloudWatch triggers and Route 53 checks
ITSM Automation Connectors         ────────── I link the Lambda to ServiceNow API to log audit records
```

### 🚫 Not My Lane (I Collaborate But Don't Own)

```text
Banking Application Logic          ────────── App developers write microservice banking functions
Database Schema & Table Keys       ────────── DBA and Data Architect design table structures
Core Network Routing (DirectConnect) ──────── Cloud Networking manages corporate backhaul circuits
ITSM Policy Approval Rules         ────────── ITSM governance determines approval requirements
```

---

## 📅 Project Duration & Timeline (10–12 Weeks)

### Phase 1: Assessment & DR Strategy (Weeks 1–2)
* Review recovery requirements and define RTO/RPO limits with the Risk Governance team.
* Research Route 53 ARC architecture; author architectural design documents.
* Register target domains and request cross-region network configuration inputs.

### Phase 2: Multi-Cluster GitOps & DB Setup (Weeks 3–5)
* Configure EKS clusters in `us-east-1` and `us-west-2` using Terraform.
* Set up ArgoCD to target both EKS APIs and synchronize application namespaces.
* Provision DynamoDB tables and enable Global Tables replication in Terraform.

### Phase 3: Route 53 ARC Routing Controls (Weeks 6–8)
* Deploy Route 53 ARC cluster, control panel, and routing controls using Terraform.
* Configure DNS record sets routing traffic conditionally based on ARC control states.
* Assist development teams in testing database behavior under cross-region latency.

### Phase 4: Automation & Ticketing Integration (Weeks 9–10)
* Develop the Failover Orchestration Lambda script (`boto3`).
* Integrate the script with the ServiceNow API to automate Emergency Change creation.
* Build CloudWatch alarms and Microsoft Teams alerts for state updates.

### Phase 5: Gameday & Verification (Weeks 11–12)
* Conduct full-scale Chaos Engineering tests (simulating complete regional outage of `us-east-1`).
* Measure and verify RTO is under 2 minutes and RPO matches DynamoDB replication logs.
* Complete ServiceNow standard change documentation and transition operational runbooks to SRE.

---

## 🔍 Step-by-Step Technical Deep-Dive

### Step 1: Infrastructure as Code (IaC) Setup
We declare the DynamoDB Global Table and the Route 53 ARC Routing Control using Terraform.

```hcl
# DynamoDB Global Table configuration
resource "aws_dynamodb_table" "usaa_banking_table" {
  name             = "usaa-banking-core"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "AccountID"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "AccountID"
    type = "S"
  }

  replica {
    region_name = "us-west-2"
  }

  tags = {
    Environment = "Production"
    Project     = "DR-Resiliency"
  }
}
```

```hcl
# Route 53 ARC Cluster configuration
resource "aws_route53recoverycontrolconfig_cluster" "dr_cluster" {
  name = "usaa-dr-global-cluster"
}

# Control Panel
resource "aws_route53recoverycontrolconfig_control_panel" "dr_control_panel" {
  name        = "usaa-banking-control-panel"
  cluster_arn = aws_route53recoverycontrolconfig_cluster.dr_cluster.arn
}

# Routing Control (Switch) for Primary
resource "aws_route53recoverycontrolconfig_routing_control" "primary_switch" {
  name              = "us-east-1-primary-switch"
  control_panel_arn = aws_route53recoverycontrolconfig_control_panel.dr_control_panel.arn
}

# Routing Control (Switch) for DR
resource "aws_route53recoverycontrolconfig_routing_control" "dr_switch" {
  name              = "us-west-2-dr-switch"
  control_panel_arn = aws_route53recoverycontrolconfig_control_panel.dr_control_panel.arn
}
```

### Step 2: Routing Control Routing Policies
We attach DNS records in Route 53 to ARC routing control states:

```hcl
resource "aws_route53_record" "primary_alb_record" {
  zone_id = var.dns_zone_id
  name    = "core-api.usaa.com"
  type    = "A"

  alias {
    name                   = var.primary_alb_dns_name
    zone_id                = var.primary_alb_zone_id
    evaluate_target_health = true
  }

  # Conditional failover based on ARC health check
  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier = "us-east-1-primary"
  health_check_id = var.primary_arc_health_check_id
}
```

---

## 🚨 ITSM Incident Management Flow

To comply with federal regulations, every regional failover is registered and tracked in ServiceNow.

### ServiceNow Ticket Mockup
During a regional disaster recovery execution, the Failover Lambda automatically submits an Emergency Change ticket:

```
EMERGENCY CHANGE REQUEST: CHG-0028172
--------------------------------------------------------------------------------
Short Description: Emergency Regional Failover: us-east-1 -> us-west-2
Assignment Group:  Platform-DevOps-Team
Status:            Closed - Complete
Priority:          1 - Critical (Production Failover)
Description:       
Automated system monitoring triggered regional failover for core-api.usaa.com due to
region degradation in us-east-1. The Orchestration Lambda validated EKS cluster state
in us-west-2, verified database replication status, and modified Route 53 ARC Routing
Controls. Primary switch us-east-1-primary-switch was set to INACTIVE. DR switch 
us-west-2-dr-switch was set to ACTIVE.

Resolution:
Global routing completed within 84 seconds. Transaction validation check completed
with zero failures. Database read/write traffic successfully redirected to us-west-2.
ITSM logs verify standard recovery procedures completed without operational blocker.
--------------------------------------------------------------------------------
```

---

## 💬 Interview Preparation (Q&A)

### Q1: What is Route 53 ARC, and how does it prevent DNS caching issues?
**Answer:** Route 53 ARC uses virtual routing controls which act as highly available switches. Traditional failovers require updating the DNS A-records in Route 53, which can take minutes or hours to propagate due to caching at ISPs and browsers. With ARC, DNS records point to routing control health checks. By toggling the routing control switch state directly via ARC's API (which sits on an active-active cluster spanning 5 regions), Route 53 instantly reports the primary node as unhealthy to queries, redirecting new connections to the standby region in seconds, avoiding DNS cache delays.

### Q2: How did you prevent "split-brain" scenario during a failover?
**Answer:** A split-brain scenario occurs if both regions believe they are active and start accepting write operations independently, resulting in database divergence. We avoided this in two ways. First, our database layer is DynamoDB Global Tables, which natively handles concurrent multi-region writes via "last-writer-wins" conflict resolution based on transaction timestamps. Second, our failover orchestrator ensures that the Routing Control switches are mutually exclusive; the script updates the state in a single transaction, setting `us-east-1` to `OFF` before or at the same time as `us-west-2` is set to `ON`.

### Q3: What is the difference between RTO and RPO, and what were your metrics?
**Answer:** RTO stands for Recovery Time Objective—it's the maximum acceptable duration of downtime before the application is restored. Our target RTO was under 2 minutes, and we achieved failover in 84 seconds. RPO stands for Recovery Point Objective—it's the maximum acceptable age of data that might be lost due to an outage. Since we use DynamoDB Global Tables with active-active replication, our cross-region replication lag averages 300ms, meaning our RPO is under 1 second, resulting in virtually no data loss.
