# USAA Event-Driven Architecture — Insurance Claims Processing Pipeline

This repository implements a production-grade, serverless **Event-Driven Architecture (EDA)** simulating how USAA processes insurance claims in real time using AWS managed services.

---

## 🏗️ Architecture Overview

```text
[ USAA Member Mobile App ]
            │
            ▼  (ClaimFiled Event)
   ┌────────────────────────────────┐
   │  Amazon EventBridge            │
   │  (usaa-claims-event-bus)       │
   │                                │
   │  Rules:                        │
   │  ├── ClaimFiled → Processor    │
   │  ├── ClaimValidated → Fraud    │
   │  ├── Status Changes → Notify   │
   │  └── ALL Events → Analytics    │
   └────────────────────────────────┘
            │
   ┌────────┼───────────┬──────────────────┐
   ▼        ▼           ▼                  ▼
[ Claims    [ Fraud      [ Notification     [ Analytics
  Processor]  Detector]    Sender]            Ingester]
   │        │           │                  │
   ▼        ▼           ▼                  ▼
DynamoDB   EventBridge  SNS + Teams       Data Lake
(persist)  (route)      (alert)           (stream)
```

---

## 📁 Repository Layout

```text
EDA/
├── .github/
│   └── workflows/
│       └── deploy.yml                    # CI/CD pipeline
├── terraform/
│   ├── providers.tf                      # AWS provider config
│   ├── variables.tf                      # Input variables
│   ├── eventbridge.tf                    # Custom event bus + routing rules
│   ├── sqs.tf                            # SQS queues with dead-letter queues
│   ├── sns.tf                            # SNS topics for notifications
│   ├── dynamodb.tf                       # Claims data store
│   ├── lambda.tf                         # 4 Lambda functions + IAM
│   └── step_functions.tf                 # Claims approval state machine
├── lambda/
│   ├── claims_processor/index.py         # Consumer 1: Validate & persist
│   ├── fraud_detector/index.py           # Consumer 2: Rule + ML scoring
│   ├── notification_sender/index.py      # Consumer 3: SNS + Teams alerts
│   └── analytics_ingester/index.py       # Consumer 4: Data lake streaming
├── Use-case_docs.md                      # Detailed architecture walkthrough
└── README.md                             # This file
```

---

## 🔧 Components

### EventBridge (Event Router)
Custom event bus with 4 rules routing events by `source` and `detail-type`:
- `ClaimFiled` → Claims Processor
- `ClaimValidated` → Fraud Detector
- `ClaimApproved / FraudDetected` → Notification Sender
- `ALL events` → Analytics Ingester

### SQS (Message Buffering)
Each consumer has its own queue with a **Dead-Letter Queue (DLQ)** to capture failed messages after 3 retries, preventing data loss.

### SNS (Fan-Out Notifications)
Two topics:
- **Claim Status**: Member-facing (email, SMS, push)
- **Fraud Alerts**: Internal SIU team alerts

### DynamoDB (Claims Store)
On-demand billing with GSIs for querying by status and member ID. Point-in-time recovery enabled for compliance.

### Step Functions (Workflow Orchestration)
State machine orchestrating the full approval flow: Validate → Fraud Check → Score Evaluation → Route (Approve / Review / SIU) → Notify → Analytics.

### Lambda Functions
| Function | Purpose |
| :--- | :--- |
| `claims_processor` | Validates claim data, persists to DynamoDB, publishes `ClaimValidated` |
| `fraud_detector` | Runs 5 rule-based checks + simulated ML scoring (0.0–1.0) |
| `notification_sender` | Sends SNS notifications to member and Teams alerts to `#claims-ops` |
| `analytics_ingester` | Streams all events to the data lake and computes real-time metrics |

---

## 🚀 Validation

```bash
# Terraform
cd terraform
terraform init -backend=false
terraform validate

# Python Lambda Syntax
python3 -m py_compile ../lambda/claims_processor/index.py
python3 -m py_compile ../lambda/fraud_detector/index.py
python3 -m py_compile ../lambda/notification_sender/index.py
python3 -m py_compile ../lambda/analytics_ingester/index.py
```
