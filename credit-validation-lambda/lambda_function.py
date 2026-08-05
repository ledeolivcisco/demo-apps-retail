"""AWS Lambda function that simulates credit validation for demo purposes.

Randomly approves or declines a credit request. Not backed by any real
credit bureau or payment processor — this exists purely to generate
realistic-looking approve/decline traffic for observability demos.

Invoked via a Lambda Function URL (API Gateway payload format 2.0), but
also works with direct test invokes (raw JSON body as the event).
"""

import json
import os
import random
import uuid
from datetime import datetime, timezone

DEFAULT_APPROVAL_RATE = 0.8
DECLINE_REASONS = [
    "Insufficient credit limit",
    "Credit score below threshold",
    "Unable to verify identity",
    "Suspicious activity detected",
]


def _approval_rate() -> float:
    try:
        rate = float(os.environ.get("APPROVAL_RATE", DEFAULT_APPROVAL_RATE))
    except ValueError:
        rate = DEFAULT_APPROVAL_RATE
    return min(max(rate, 0.0), 1.0)


def _parse_body(event: dict) -> dict:
    """Extract a JSON dict from either a Function URL event or a raw test event."""
    body = event.get("body") if isinstance(event, dict) else None

    if body is None:
        # Direct invoke (e.g. `aws lambda invoke` with a raw JSON payload).
        return event if isinstance(event, dict) else {}

    if event.get("isBase64Encoded"):
        import base64

        body = base64.b64decode(body).decode("utf-8")

    if not body:
        return {}

    try:
        parsed = json.loads(body)
        return parsed if isinstance(parsed, dict) else {}
    except (json.JSONDecodeError, TypeError):
        return {}


def _validate_credit(payload: dict) -> dict:
    approved = random.random() < _approval_rate()

    result = {
        "requestId": str(uuid.uuid4()),
        "status": "approved" if approved else "declined",
        "reason": "Approved" if approved else random.choice(DECLINE_REASONS),
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }

    if "amount" in payload:
        result["amount"] = payload["amount"]
    if "cardLast4" in payload:
        result["cardLast4"] = payload["cardLast4"]

    return result


def handler(event, context):
    payload = _parse_body(event)
    result = _validate_credit(payload)

    # Only wrap in the API Gateway/Function URL response shape when invoked
    # through HTTP; plain test invokes just get the result dict back.
    if isinstance(event, dict) and "requestContext" in event:
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(result),
        }

    return result
