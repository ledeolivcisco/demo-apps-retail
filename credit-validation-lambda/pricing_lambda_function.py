"""AWS Lambda function that simulates appliance pricing for demo purposes.

Returns a random price between 100 and 5000 on every invocation — not backed
by any real pricing engine. Useful for generating volatile pricing traffic
in observability demos.

Invoked via API Gateway (payload format 2.0), but also works with direct
test invokes (raw JSON body as the event).
"""

import json
import os
import random
import uuid
from datetime import datetime, timezone

DEFAULT_PRICE_MIN = 100
DEFAULT_PRICE_MAX = 5000


def _price_bounds() -> tuple[int, int]:
    try:
        price_min = int(os.environ.get("PRICE_MIN", DEFAULT_PRICE_MIN))
        price_max = int(os.environ.get("PRICE_MAX", DEFAULT_PRICE_MAX))
    except ValueError:
        price_min = DEFAULT_PRICE_MIN
        price_max = DEFAULT_PRICE_MAX

    if price_min > price_max:
        price_min, price_max = price_max, price_min

    return price_min, price_max


def _parse_body(event: dict) -> dict:
    """Extract a JSON dict from either a Function URL event or a raw test event."""
    body = event.get("body") if isinstance(event, dict) else None

    if body is None:
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


def _price_for_sku(payload: dict) -> tuple[int, dict]:
    sku = payload.get("sku")
    if not sku or not str(sku).strip():
        return 400, {"error": "sku is required"}

    price_min, price_max = _price_bounds()
    result = {
        "requestId": str(uuid.uuid4()),
        "sku": str(sku).strip(),
        "price": random.randint(price_min, price_max),
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    return 200, result


def handler(event, context):
    payload = _parse_body(event)
    status_code, result = _price_for_sku(payload)

    if isinstance(event, dict) and "requestContext" in event:
        return {
            "statusCode": status_code,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(result),
        }

    return result
