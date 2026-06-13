"""
Notification Sender Lambda — Consumer #3
Receives claim status events (ClaimApproved, ClaimFlaggedForReview, FraudDetected)
and delivers notifications via SNS (email/SMS to member) and Teams webhooks
(real-time alerts to the #claims-ops channel).
"""
import os
import json
import logging
import urllib.request
import urllib.error
from datetime import datetime

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sns_client = boto3.client("sns")

SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")
FRAUD_SNS_TOPIC_ARN = os.environ.get("FRAUD_SNS_TOPIC_ARN", "")
TEAMS_WEBHOOK_URL = os.environ.get("TEAMS_WEBHOOK_URL", "")

# Status-to-notification mapping
STATUS_CONFIG = {
    "APPROVED": {
        "color": "00FF00",
        "icon": "✅",
        "title": "Claim Approved",
        "member_subject": "USAA: Your Insurance Claim Has Been Approved",
    },
    "PENDING_REVIEW": {
        "color": "FFA500",
        "icon": "⚠️",
        "title": "Claim Flagged for Manual Review",
        "member_subject": "USAA: Your Insurance Claim Is Under Review",
    },
    "FRAUD_FLAGGED": {
        "color": "FF0000",
        "icon": "🚨",
        "title": "CRITICAL: Potential Fraud Detected",
        "member_subject": "USAA: Your Insurance Claim Is Being Reviewed",
    },
    "PROCESSING_ERROR": {
        "color": "800080",
        "icon": "❌",
        "title": "Claim Processing Error",
        "member_subject": "USAA: We're Looking Into Your Claim",
    },
}


def send_member_notification(claim_data, status, message):
    """Publish a notification to the member via SNS (email, SMS, push)."""
    config = STATUS_CONFIG.get(status, STATUS_CONFIG["PROCESSING_ERROR"])
    claim_id = claim_data.get("claimId", "N/A")
    member_id = claim_data.get("memberId", "N/A")

    sns_message = (
        f"Dear USAA Member ({member_id}),\n\n"
        f"Claim ID: {claim_id}\n"
        f"Status: {status}\n\n"
        f"{message}\n\n"
        f"If you have questions, please contact us at 1-800-531-USAA (8722).\n\n"
        f"— USAA Claims Team"
    )

    try:
        if SNS_TOPIC_ARN:
            sns_client.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject=config["member_subject"],
                Message=sns_message,
            )
            logger.info(f"Member notification sent via SNS for claim {claim_id}")
        else:
            logger.info(f"SNS_TOPIC_ARN not set. Logging notification:\n{sns_message}")
    except Exception as e:
        logger.error(f"Failed to send member SNS notification: {e}")


def send_fraud_alert(claim_data, fraud_score, triggered_rules):
    """Publish a critical fraud alert to the SIU team via the fraud SNS topic."""
    claim_id = claim_data.get("claimId", "N/A")
    member_id = claim_data.get("memberId", "N/A")

    alert_message = (
        f"🚨 FRAUD ALERT — Special Investigations Unit\n"
        f"{'=' * 50}\n"
        f"Claim ID:         {claim_id}\n"
        f"Member ID:        {member_id}\n"
        f"Claim Type:       {claim_data.get('claimType', 'N/A')}\n"
        f"Estimated Amount: ${claim_data.get('estimatedAmount', 'N/A')}\n"
        f"Fraud Score:      {fraud_score}\n"
        f"Triggered Rules:  {', '.join(triggered_rules) if triggered_rules else 'ML Model Flag'}\n"
        f"{'=' * 50}\n"
        f"Action Required: Assign SIU investigator immediately.\n"
    )

    try:
        if FRAUD_SNS_TOPIC_ARN:
            sns_client.publish(
                TopicArn=FRAUD_SNS_TOPIC_ARN,
                Subject=f"🚨 FRAUD ALERT: Claim {claim_id} (Score: {fraud_score})",
                Message=alert_message,
            )
            logger.info(f"Fraud alert sent to SIU via SNS for claim {claim_id}")
        else:
            logger.info(f"FRAUD_SNS_TOPIC_ARN not set. Logging alert:\n{alert_message}")
    except Exception as e:
        logger.error(f"Failed to send fraud SNS alert: {e}")


def send_teams_notification(claim_data, status, fraud_score=None, triggered_rules=None):
    """Send a rich notification card to Microsoft Teams via incoming webhook."""
    if not TEAMS_WEBHOOK_URL:
        logger.info("TEAMS_WEBHOOK_URL not set. Skipping Teams notification.")
        return

    config = STATUS_CONFIG.get(status, STATUS_CONFIG["PROCESSING_ERROR"])
    claim_id = claim_data.get("claimId", "N/A")

    facts = [
        {"name": "Claim ID", "value": claim_id},
        {"name": "Member ID", "value": claim_data.get("memberId", "N/A")},
        {"name": "Claim Type", "value": claim_data.get("claimType", "N/A")},
        {"name": "Amount", "value": f"${claim_data.get('estimatedAmount', 'N/A')}"},
        {"name": "Status", "value": status},
        {"name": "Timestamp", "value": datetime.utcnow().isoformat()},
    ]

    if fraud_score is not None:
        facts.append({"name": "Fraud Score", "value": str(fraud_score)})
    if triggered_rules:
        facts.append({"name": "Triggered Rules", "value": ", ".join(triggered_rules)})

    payload = {
        "@type": "MessageCard",
        "@context": "http://schema.org/extensions",
        "themeColor": config["color"],
        "summary": f"{config['icon']} {config['title']} — {claim_id}",
        "sections": [
            {
                "activityTitle": f"{config['icon']} {config['title']}",
                "activitySubtitle": f"Claim Pipeline — {var.project_name if 'var' in dir() else 'USAA Claims'}",
                "facts": facts,
                "markdown": True,
            }
        ],
    }

    try:
        req = urllib.request.Request(
            TEAMS_WEBHOOK_URL,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req) as resp:
            logger.info(f"Teams notification sent. Status: {resp.status}")
    except urllib.error.URLError as e:
        logger.warning(f"Teams webhook call failed: {e}")
    except Exception as e:
        logger.warning(f"Unexpected error sending Teams notification: {e}")


def handler(event, context):
    """Main Lambda entry point."""
    logger.info(f"Received event: {json.dumps(event)}")

    detail = event.get("detail", event)
    claim_data = detail if isinstance(detail, dict) else json.loads(detail)

    status = claim_data.get("status", claim_data.get("claimStatus", "UNKNOWN"))
    message = claim_data.get("message", "Your claim status has been updated.")
    fraud_score = claim_data.get("fraudScore")
    triggered_rules = claim_data.get("triggeredRules", [])

    # Determine status from event type if not in detail
    event_type = event.get("detail-type", "")
    if event_type == "ClaimApproved":
        status = "APPROVED"
    elif event_type == "ClaimFlaggedForReview":
        status = "PENDING_REVIEW"
    elif event_type == "FraudDetected":
        status = "FRAUD_FLAGGED"

    # 1. Send member-facing notification via SNS
    send_member_notification(claim_data, status, message)

    # 2. If fraud flagged, send critical alert to SIU
    if status == "FRAUD_FLAGGED":
        send_fraud_alert(claim_data, fraud_score, triggered_rules)

    # 3. Send real-time Teams notification to #claims-ops
    send_teams_notification(claim_data, status, fraud_score, triggered_rules)

    return {
        "statusCode": 200,
        "claimId": claim_data.get("claimId"),
        "notificationStatus": status,
        "channels": ["SNS", "Teams"] + (["SIU-Alert"] if status == "FRAUD_FLAGGED" else []),
    }
