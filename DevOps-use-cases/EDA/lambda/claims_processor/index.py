"""
Claims Processor Lambda — Consumer #1
Receives ClaimFiled events from EventBridge, validates the claim data,
persists it to DynamoDB, and publishes a ClaimValidated event downstream.
"""
import os
import json
import logging
import uuid
from datetime import datetime

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
events_client = boto3.client("events")

TABLE_NAME = os.environ.get("DYNAMODB_TABLE", "usaa-claims-store")
EVENT_BUS = os.environ.get("EVENT_BUS_NAME", "usaa-claims-event-bus")

REQUIRED_FIELDS = ["memberId", "claimType", "incidentDate", "description", "estimatedAmount"]


def validate_claim(claim_data):
    """Validate that all required fields are present and within expected ranges."""
    missing = [f for f in REQUIRED_FIELDS if f not in claim_data or not claim_data[f]]
    if missing:
        raise ValueError(f"Missing required fields: {', '.join(missing)}")

    # Business rule: Estimated amount must be positive and under $500,000
    amount = float(claim_data.get("estimatedAmount", 0))
    if amount <= 0 or amount > 500000:
        raise ValueError(f"Estimated amount ${amount} is outside the acceptable range ($1 - $500,000)")

    # Business rule: Incident date cannot be in the future
    incident_date = datetime.fromisoformat(claim_data["incidentDate"])
    if incident_date > datetime.utcnow():
        raise ValueError("Incident date cannot be in the future")

    return True


def persist_claim(claim_id, claim_data):
    """Write the validated claim record to DynamoDB."""
    table = dynamodb.Table(TABLE_NAME)
    now = datetime.utcnow().isoformat()

    item = {
        "claimId": claim_id,
        "memberId": claim_data["memberId"],
        "claimType": claim_data["claimType"],
        "incidentDate": claim_data["incidentDate"],
        "description": claim_data["description"],
        "estimatedAmount": str(claim_data["estimatedAmount"]),
        "claimStatus": "VALIDATED",
        "createdAt": now,
        "updatedAt": now,
        "vehicleVIN": claim_data.get("vehicleVIN", "N/A"),
        "location": claim_data.get("location", "N/A"),
    }

    table.put_item(Item=item)
    logger.info(f"Persisted claim {claim_id} to DynamoDB")
    return item


def publish_validated_event(claim_id, claim_data):
    """Publish a ClaimValidated event to EventBridge for downstream consumers."""
    response = events_client.put_events(
        Entries=[
            {
                "Source": "usaa.claims.processor",
                "DetailType": "ClaimValidated",
                "Detail": json.dumps({
                    "claimId": claim_id,
                    "memberId": claim_data["memberId"],
                    "claimType": claim_data["claimType"],
                    "estimatedAmount": claim_data["estimatedAmount"],
                    "incidentDate": claim_data["incidentDate"],
                    "vehicleVIN": claim_data.get("vehicleVIN", "N/A"),
                    "validatedAt": datetime.utcnow().isoformat(),
                }),
                "EventBusName": EVENT_BUS,
            }
        ]
    )
    logger.info(f"Published ClaimValidated event for {claim_id}: {response}")


def handler(event, context):
    """Main Lambda entry point."""
    logger.info(f"Received event: {json.dumps(event)}")

    # Extract claim data from EventBridge event envelope
    detail = event.get("detail", event)
    claim_data = detail if isinstance(detail, dict) else json.loads(detail)

    # Generate unique claim ID
    claim_id = claim_data.get("claimId", f"CLM-{uuid.uuid4().hex[:8].upper()}")

    try:
        # Step 1: Validate the claim
        validate_claim(claim_data)
        logger.info(f"Claim {claim_id} passed validation")

        # Step 2: Persist to DynamoDB
        persisted_item = persist_claim(claim_id, claim_data)

        # Step 3: Publish downstream event
        publish_validated_event(claim_id, claim_data)

        return {
            "statusCode": 200,
            "claimId": claim_id,
            "memberId": claim_data["memberId"],
            "claimStatus": "VALIDATED",
            "message": f"Claim {claim_id} validated and persisted successfully",
        }

    except ValueError as e:
        logger.error(f"Validation failed for claim {claim_id}: {e}")
        return {
            "statusCode": 400,
            "claimId": claim_id,
            "claimStatus": "VALIDATION_FAILED",
            "error": str(e),
        }
    except Exception as e:
        logger.error(f"Unexpected error processing claim {claim_id}: {e}")
        raise
