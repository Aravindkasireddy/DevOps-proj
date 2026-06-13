"""
Analytics Ingester Lambda — Consumer #4
Receives ALL claim events from EventBridge and streams them to the
analytics data store (DynamoDB events log) for dashboards and reporting.

In production, this would also write to:
- Amazon Kinesis Data Firehose → S3 Data Lake (Parquet format)
- Amazon Redshift (via Redshift Streaming Ingestion)
- Amazon OpenSearch for real-time search/dashboards
"""
import os
import json
import logging
from datetime import datetime

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ.get("DYNAMODB_TABLE", "usaa-claims-store")


def stream_to_data_lake(event_record):
    """
    In production, this function would write to Kinesis Data Firehose:

        firehose_client.put_record(
            DeliveryStreamName='usaa-claims-analytics-stream',
            Record={'Data': json.dumps(event_record).encode('utf-8')}
        )

    For this demo, we log the record structure that would be streamed.
    """
    logger.info(f"[DATA LAKE STREAM] {json.dumps(event_record)}")


def update_analytics_metadata(claim_id, member_id, event_type):
    """Update the claim record in DynamoDB with the latest event for audit trail."""
    table = dynamodb.Table(TABLE_NAME)
    now = datetime.utcnow().isoformat()

    try:
        table.update_item(
            Key={"claimId": claim_id, "memberId": member_id},
            UpdateExpression=(
                "SET lastEventType = :evt, lastEventTimestamp = :ts, updatedAt = :now"
            ),
            ExpressionAttributeValues={
                ":evt": event_type,
                ":ts": now,
                ":now": now,
            },
        )
        logger.info(f"Updated analytics metadata for claim {claim_id}")
    except Exception as e:
        # Non-blocking — analytics should never fail the pipeline
        logger.warning(f"DynamoDB analytics update failed (non-critical): {e}")


def compute_metrics(event_type, detail):
    """
    Compute real-time metrics that would feed into CloudWatch custom metrics
    or a Grafana/Datadog dashboard.
    """
    metrics = {
        "timestamp": datetime.utcnow().isoformat(),
        "eventType": event_type,
        "claimId": detail.get("claimId", "unknown"),
        "claimType": detail.get("claimType", "unknown"),
        "estimatedAmount": detail.get("estimatedAmount", 0),
    }

    # Add fraud-specific metrics
    if event_type in ["ClaimApproved", "ClaimFlaggedForReview", "FraudDetected"]:
        metrics["fraudScore"] = detail.get("fraudScore", 0)
        metrics["triggeredRulesCount"] = len(detail.get("triggeredRules", []))

    # In production: publish to CloudWatch Metrics
    # cloudwatch.put_metric_data(
    #     Namespace='USAA/Claims',
    #     MetricData=[{
    #         'MetricName': 'ClaimProcessed',
    #         'Dimensions': [{'Name': 'EventType', 'Value': event_type}],
    #         'Value': 1,
    #         'Unit': 'Count'
    #     }]
    # )

    logger.info(f"[METRICS] {json.dumps(metrics)}")
    return metrics


def handler(event, context):
    """Main Lambda entry point — processes every claim event for analytics."""
    logger.info(f"Received analytics event: {json.dumps(event)}")

    event_type = event.get("detail-type", "Unknown")
    source = event.get("source", "unknown")
    detail = event.get("detail", {})

    claim_id = detail.get("claimId", "unknown")
    member_id = detail.get("memberId", "unknown")

    # Build the analytics record
    analytics_record = {
        "eventId": event.get("id", "unknown"),
        "eventType": event_type,
        "source": source,
        "claimId": claim_id,
        "memberId": member_id,
        "timestamp": event.get("time", datetime.utcnow().isoformat()),
        "detail": detail,
        "ingestedAt": datetime.utcnow().isoformat(),
    }

    # 1. Stream to data lake (Kinesis/S3 in production)
    stream_to_data_lake(analytics_record)

    # 2. Update DynamoDB audit trail
    if claim_id != "unknown" and member_id != "unknown":
        update_analytics_metadata(claim_id, member_id, event_type)

    # 3. Compute and publish real-time metrics
    metrics = compute_metrics(event_type, detail)

    return {
        "statusCode": 200,
        "claimId": claim_id,
        "eventType": event_type,
        "analyticsStatus": "INGESTED",
        "metrics": metrics,
    }
