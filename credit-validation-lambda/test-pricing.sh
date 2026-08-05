#!/usr/bin/env bash
# Quick smoke test for appliance-pricing-lambda's public endpoint.
# Auto-discovers the API Gateway URL, then fires sample requests.

set -euo pipefail

API_NAME="appliance-pricing-api"

API_ID="$(aws apigatewayv2 get-apis --query "Items[?Name=='${API_NAME}'].ApiId" --output text)"
if [ -z "${API_ID}" ] || [ "${API_ID}" == "None" ]; then
  echo "Could not find API Gateway '${API_NAME}'. Has it been deployed? Run ./deploy-pricing.sh first." >&2
  exit 1
fi

API_URL="$(aws apigatewayv2 get-api --api-id "${API_ID}" --query 'ApiEndpoint' --output text)"
echo "Testing ${API_URL}"
echo ""

for sku in WASH-001 FRIDGE-002 OVEN-003; do
  echo "--- SKU: ${sku} ---"
  curl -s -X POST "${API_URL}" \
    -H 'content-type: application/json' \
    -d "{\"sku\": \"${sku}\"}" | python3 -m json.tool
  echo ""
done

echo "--- Same SKU twice (WASH-001) — prices should differ ---"
for i in 1 2; do
  echo "Request ${i}:"
  curl -s -X POST "${API_URL}" \
    -H 'content-type: application/json' \
    -d '{"sku": "WASH-001"}' | python3 -m json.tool
  echo ""
done

echo "--- Missing SKU (expect error) ---"
curl -s -X POST "${API_URL}" \
  -H 'content-type: application/json' \
  -d '{}' | python3 -m json.tool
