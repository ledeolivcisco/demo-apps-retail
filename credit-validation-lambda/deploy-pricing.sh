#!/usr/bin/env bash
# Deploys (or updates) the appliance-pricing-lambda function using only the AWS CLI.
#
# Creates:
#   - IAM role "appliance-pricing-lambda-role" (basic Lambda execution / CloudWatch Logs)
#   - Lambda function "appliance-pricing-lambda" (Python 3.13), instrumented with the
#     Splunk OpenTelemetry Lambda layer (traces + metrics to Splunk Observability Cloud)
#   - A public HTTP API Gateway in front of it (no auth) — demo only.
#
# Note: Lambda Function URLs (lambda:CreateFunctionUrlConfig) are blocked by an
# AWS Organizations SCP on this account, so API Gateway (HTTP API) is used
# instead to expose a public HTTPS endpoint.
#
# Requires a .env file (see .env.example) with SPLUNK_REALM and SPLUNK_ACCESS_TOKEN.
#
# Safe to re-run: skips/updates existing resources instead of failing.

set -euo pipefail

FUNCTION_NAME="appliance-pricing-lambda"
ROLE_NAME="appliance-pricing-lambda-role"
API_NAME="appliance-pricing-api"
RUNTIME="python3.13"
HANDLER="pricing_lambda_function.handler"
REGION="$(aws configure get region)"
REGION="${REGION:-us-east-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query 'Account' --output text)"

SPLUNK_LAMBDA_LAYER_ARN="${SPLUNK_LAMBDA_LAYER_ARN:-arn:aws:lambda:us-east-1:254067382080:layer:splunk-apm:137}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build-pricing"
ZIP_PATH="${BUILD_DIR}/function.zip"

if [ -f "${SCRIPT_DIR}/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/.env"
  set +a
fi

: "${SPLUNK_REALM:?Missing SPLUNK_REALM — copy .env.example to .env and fill it in}"
: "${SPLUNK_ACCESS_TOKEN:?Missing SPLUNK_ACCESS_TOKEN — copy .env.example to .env and fill it in}"
OTEL_SERVICE_NAME="${APPLIANCE_PRICING_OTEL_SERVICE_NAME:-appliance-pricing-lambda}"
DEPLOYMENT_ENV="${DEPLOYMENT_ENV:-dev}"

echo "Region: ${REGION}"

# --- IAM role -----------------------------------------------------------
if aws iam get-role --role-name "${ROLE_NAME}" >/dev/null 2>&1; then
  echo "IAM role ${ROLE_NAME} already exists, reusing it."
else
  echo "Creating IAM role ${ROLE_NAME}..."
  TRUST_POLICY=$(cat <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
)
  aws iam create-role \
    --role-name "${ROLE_NAME}" \
    --assume-role-policy-document "${TRUST_POLICY}" \
    --description "Execution role for the appliance-pricing-lambda demo function" \
    >/dev/null

  aws iam attach-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

  echo "Waiting for IAM role to propagate..."
  sleep 10
fi

ROLE_ARN="$(aws iam get-role --role-name "${ROLE_NAME}" --query 'Role.Arn' --output text)"
echo "Role ARN: ${ROLE_ARN}"

# --- Package --------------------------------------------------------------
echo "Packaging function code..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
(cd "${SCRIPT_DIR}" && zip -q "${ZIP_PATH}" pricing_lambda_function.py)

# --- Environment variables (function config + Splunk OTel instrumentation) --
ENV_JSON="${BUILD_DIR}/environment.json"
jq -n \
  --arg priceMin "100" \
  --arg priceMax "5000" \
  --arg splunkRealm "${SPLUNK_REALM}" \
  --arg splunkToken "${SPLUNK_ACCESS_TOKEN}" \
  --arg serviceName "${OTEL_SERVICE_NAME}" \
  --arg deploymentEnv "deployment.environment=${DEPLOYMENT_ENV}" \
  '{Variables: {
    PRICE_MIN: $priceMin,
    PRICE_MAX: $priceMax,
    AWS_LAMBDA_EXEC_WRAPPER: "/opt/otel-instrument",
    SPLUNK_REALM: $splunkRealm,
    SPLUNK_ACCESS_TOKEN: $splunkToken,
    OTEL_SERVICE_NAME: $serviceName,
    OTEL_RESOURCE_ATTRIBUTES: $deploymentEnv,
    OTEL_LOGS_EXPORTER: "none"
  }}' > "${ENV_JSON}"

# --- Create or update function --------------------------------------------
if aws lambda get-function --function-name "${FUNCTION_NAME}" >/dev/null 2>&1; then
  echo "Function ${FUNCTION_NAME} exists, updating code..."
  aws lambda update-function-code \
    --function-name "${FUNCTION_NAME}" \
    --zip-file "fileb://${ZIP_PATH}" \
    >/dev/null

  aws lambda wait function-updated --function-name "${FUNCTION_NAME}"

  aws lambda update-function-configuration \
    --function-name "${FUNCTION_NAME}" \
    --runtime "${RUNTIME}" \
    --handler "${HANDLER}" \
    --timeout 15 \
    --layers "${SPLUNK_LAMBDA_LAYER_ARN}" \
    --environment "file://${ENV_JSON}" \
    >/dev/null

  aws lambda wait function-updated --function-name "${FUNCTION_NAME}"
else
  echo "Creating function ${FUNCTION_NAME}..."
  aws lambda create-function \
    --function-name "${FUNCTION_NAME}" \
    --runtime "${RUNTIME}" \
    --handler "${HANDLER}" \
    --role "${ROLE_ARN}" \
    --zip-file "fileb://${ZIP_PATH}" \
    --timeout 15 \
    --memory-size 128 \
    --layers "${SPLUNK_LAMBDA_LAYER_ARN}" \
    --environment "file://${ENV_JSON}" \
    --description "Simulates appliance pricing, returns random price per SKU (demo only)" \
    >/dev/null

  aws lambda wait function-active --function-name "${FUNCTION_NAME}"
fi

# --- Public API Gateway (HTTP API) -----------------------------------------
API_ID="$(aws apigatewayv2 get-apis --query "Items[?Name=='${API_NAME}'].ApiId" --output text)"

if [ -n "${API_ID}" ] && [ "${API_ID}" != "None" ]; then
  echo "API Gateway ${API_NAME} already exists (${API_ID}), reusing it."
else
  echo "Creating API Gateway HTTP API ${API_NAME}..."
  API_ID="$(aws apigatewayv2 create-api \
    --name "${API_NAME}" \
    --protocol-type HTTP \
    --target "arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:${FUNCTION_NAME}" \
    --query 'ApiId' --output text)"
fi

aws lambda add-permission \
  --function-name "${FUNCTION_NAME}" \
  --statement-id "ApiGatewayInvoke" \
  --action "lambda:InvokeFunction" \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*" \
  >/dev/null 2>&1 || true

API_URL="$(aws apigatewayv2 get-api --api-id "${API_ID}" --query 'ApiEndpoint' --output text)"

echo ""
echo "Deployed successfully."
echo "Public endpoint: ${API_URL}"
echo ""
echo "NOTE: a destroy/deploy cycle mints a NEW API id. Update APPLIANCE_PRICING_LAMBDA_URL"
echo "      in the compose .env files (docker/, docker-standalone/, docker-standalone-o11y/)"
echo "      to the endpoint above, or appliance-service will call a dead URL when GET_PRICE=true."
echo ""
echo "Try it:"
echo "  curl -s -X POST '${API_URL}' -H 'content-type: application/json' -d '{\"sku\": \"WASH-001\"}' | python3 -m json.tool"
