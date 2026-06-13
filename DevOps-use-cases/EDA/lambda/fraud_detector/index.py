"""
Fraud Detector Lambda — Consumer #2
Receives ClaimValidated events, runs rule-based checks and a mock ML
risk-scoring model, then publishes ClaimApproved, ClaimFlaggedForReview,
or FraudDetected events based on the computed risk score.
"""
import os
import json
import logging
import hashlib
from datetime import datetime, timedelta

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
events_client = boto3.client("events")

TABLE_NAME = os.environ.get("DYNAMODB_TABLE", "usaa-claims-store")
EVENT_BUS = os.environ.get("EVENT_BUS_NAME", "usaa-claims-event-bus")

# ============================================================================
# LAYER 1: Rule-Based Fraud Checks (Deterministic — Instant)
# ============================================================================

RULES = [
    {
        "name": "HIGH_CLAIM_AMOUNT",
        "description": "Claim amount exceeds 80% of typical vehicle value",
        "weight": 0.25,
    },
    {
        "name": "RECENT_POLICY_START",
        "description": "Claim filed within 30 days of policy activation",
        "weight": 0.30,
    },
    {
        "name": "MULTIPLE_RECENT_CLAIMS",
        "description": "Member has filed 3+ claims in the past 12 months",
        "weight": 0.35,
    },
    {
        "name": "GEOGRAPHIC_ANOMALY",
        "description": "Claim location does not match policy registration state",
        "weight": 0.20,
    },
    {
        "name": "WEEKEND_NIGHT_INCIDENT",
        "description": "Incident occurred between Friday 10PM and Monday 6AM",
        "weight": 0.10,
    },
]


def run_rule_checks(claim_data):
    """Execute deterministic rule-based fraud checks. Returns list of triggered rules."""
    triggered_rules = []
    amount = float(claim_data.get("estimatedAmount", 0))

    # Rule 1: High claim amount (over $25,000 for auto claims)
    if claim_data.get("claimType") == "auto_collision" and amount > 25000:
        triggered_rules.append("HIGH_CLAIM_AMOUNT")

    # Rule 2: Recent policy start (simulated — check if incidentDate is very recent)
    try:
        incident = datetime.fromisoformat(claim_data["incidentDate"])
        # Simulating: if the claim is filed same day as incident, flag it
        if (datetime.utcnow() - incident) < timedelta(days=1):
            triggered_rules.append("RECENT_POLICY_START")
    except (ValueError, KeyError):
        pass

    # Rule 3: Weekend/night incident
    try:
        incident = datetime.fromisoformat(claim_data["incidentDate"])
        if incident.weekday() >= 5 or incident.hour >= 22 or incident.hour <= 6:
            triggered_rules.append("WEEKEND_NIGHT_INCIDENT")
    except (ValueError, KeyError):
        pass

    logger.info(f"Rule checks complete. Triggered: {triggered_rules}")
    return triggered_rules


# ============================================================================
# LAYER 2: ML Model Scoring (Simulated — Would call SageMaker in production)
# ============================================================================

def compute_fraud_score(claim_data, triggered_rules):
    """
    Simulate an ML fraud score between 0.0 and 1.0.

    In production, this would call an Amazon SageMaker real-time inference endpoint:
        sagemaker_client.invoke_endpoint(
            EndpointName='usaa-fraud-model-v3',
            Body=json.dumps(features),
            ContentType='application/json'
        )

    For this demo, we use a deterministic scoring formula based on rule triggers
    and claim characteristics to produce repeatable, explainable results.
    """
    base_score = 0.05  # Every claim starts with a minimal baseline risk

    # Add weight for each triggered rule
    rule_weights = {r["name"]: r["weight"] for r in RULES}
    for rule_name in triggered_rules:
        base_score += rule_weights.get(rule_name, 0.1)

    # Factor in claim amount (higher amounts = slightly higher risk)
    amount = float(claim_data.get("estimatedAmount", 0))
    if amount > 50000:
        base_score += 0.15
    elif amount > 15000:
        base_score += 0.05

    # Use a hash of the claimId for deterministic "randomness" in the demo
    claim_hash = int(hashlib.md5(
        claim_data.get("claimId", "unknown").encode()
    ).hexdigest()[:4], 16)
    jitter = (claim_hash % 10) / 100  # Adds 0.00 to 0.09 jitter
    base_score += jitter

    # Cap score at 1.0
    final_score = min(round(base_score, 2), 1.0)
    logger.info(f"Fraud score computed: {final_score}")
    return final_score


def determine_outcome(fraud_score):
    """Classify the claim based on fraud score thresholds."""
    if fraud_score > 0.7:
        return "FraudDetected", "FRAUD_FLAGGED"
    elif fraud_score > 0.3:
        return "ClaimFlaggedForReview", "PENDING_REVIEW"
    else:
        return "ClaimApproved", "APPROVED"


def update_claim_status(claim_id, member_id, status, fraud_score):
    """Update the claim record in DynamoDB with the fraud assessment results."""
    table = dynamodb.Table(TABLE_NAME)
    table.update_item(
        Key={"claimId": claim_id, "memberId": member_id},
        UpdateExpression="SET claimStatus = :status, fraudScore = :score, updatedAt = :now",
        ExpressionAttributeValues={
            ":status": status,
            ":score": str(fraud_score),
            ":now": datetime.utcnow().isoformat(),
        },
    )
    logger.info(f"Updated claim {claim_id} status to {status}")


def publish_outcome_event(claim_data, event_type, fraud_score, triggered_rules):
    """Publish the fraud assessment outcome to EventBridge."""
    claim_id = claim_data.get("claimId", "unknown")
    response = events_client.put_events(
        Entries=[
            {
                "Source": "usaa.claims.fraud-detector",
                "DetailType": event_type,
                "Detail": json.dumps({
                    "claimId": claim_id,
                    "memberId": claim_data.get("memberId"),
                    "claimType": claim_data.get("claimType"),
                    "estimatedAmount": claim_data.get("estimatedAmount"),
                    "fraudScore": fraud_score,
                    "triggeredRules": triggered_rules,
                    "assessedAt": datetime.utcnow().isoformat(),
                }),
                "EventBusName": EVENT_BUS,
            }
        ]
    )
    logger.info(f"Published {event_type} event for claim {claim_id}: {response}")


def handler(event, context):
    """Main Lambda entry point."""
    logger.info(f"Received event: {json.dumps(event)}")

    detail = event.get("detail", event)
    claim_data = detail if isinstance(detail, dict) else json.loads(detail)

    claim_id = claim_data.get("claimId", "unknown")
    member_id = claim_data.get("memberId", "unknown")

    # Layer 1: Rule-based checks
    triggered_rules = run_rule_checks(claim_data)

    # Layer 2: ML model scoring
    fraud_score = compute_fraud_score(claim_data, triggered_rules)

    # Determine outcome
    event_type, claim_status = determine_outcome(fraud_score)
    logger.info(f"Claim {claim_id} outcome: {event_type} (score: {fraud_score})")

    # Update DynamoDB
    try:
        update_claim_status(claim_id, member_id, claim_status, fraud_score)
    except Exception as e:
        logger.warning(f"DynamoDB update failed (non-blocking): {e}")

    # Publish downstream event
    publish_outcome_event(claim_data, event_type, fraud_score, triggered_rules)

    return {
        "statusCode": 200,
        "claimId": claim_id,
        "memberId": member_id,
        "fraudScore": fraud_score,
        "triggeredRules": triggered_rules,
        "outcome": event_type,
        "claimStatus": claim_status,
    }
