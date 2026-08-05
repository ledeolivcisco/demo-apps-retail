#!/usr/bin/env bash
# Quick smoke test for credit-validation-lambda's public endpoint.
# Auto-discovers the API Gateway URL, then fires a few sample requests.

set -euo pipefail

API_NAME="credit-validation-api"

API_ID="$(aws apigatewayv2 get-apis --query "Items[?Name=='${API_NAME}'].ApiId" --output text)"
if [ -z "${API_ID}" ] || [ "${API_ID}" == "None" ]; then
  echo "Could not find API Gateway '${API_NAME}'. Has it been deployed? Run ./deploy.sh first." >&2
  exit 1
fi

API_URL="$(aws apigatewayv2 get-api --api-id "${API_ID}" --query 'ApiEndpoint' --output text)"
echo "Testing ${API_URL}"
echo ""

for i in 1 2 3 4 5; do
  echo "--- Request ${i} ---"
  curl -s -X POST "${API_URL}" \
    -H 'content-type: application/json' \
    -d '{"amount": 129.99, "cardLast4": "1111"}' | python3 -m json.tool
  echo ""
done
