#!/usr/bin/env bash
# Tears down everything created by deploy.sh:
#   - API Gateway HTTP API "credit-validation-api"
#   - Lambda function "credit-validation-lambda"
#   - IAM role "credit-validation-lambda-role"
#   - Local build artifacts
#
# Safe to re-run: skips resources that don't exist instead of failing.

set -uo pipefail

FUNCTION_NAME="credit-validation-lambda"
ROLE_NAME="credit-validation-lambda-role"
API_NAME="credit-validation-api"
POLICY_ARN="arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- API Gateway ------------------------------------------------------------
API_ID="$(aws apigatewayv2 get-apis --query "Items[?Name=='${API_NAME}'].ApiId" --output text 2>/dev/null)"
if [ -n "${API_ID}" ] && [ "${API_ID}" != "None" ]; then
  echo "Deleting API Gateway ${API_NAME} (${API_ID})..."
  aws apigatewayv2 delete-api --api-id "${API_ID}"
else
  echo "API Gateway ${API_NAME} not found, skipping."
fi

# --- Lambda function ---------------------------------------------------------
if aws lambda get-function --function-name "${FUNCTION_NAME}" >/dev/null 2>&1; then
  echo "Deleting Lambda function ${FUNCTION_NAME}..."
  aws lambda delete-function --function-name "${FUNCTION_NAME}"
else
  echo "Lambda function ${FUNCTION_NAME} not found, skipping."
fi

# --- IAM role -----------------------------------------------------------
if aws iam get-role --role-name "${ROLE_NAME}" >/dev/null 2>&1; then
  echo "Detaching policy and deleting IAM role ${ROLE_NAME}..."
  aws iam detach-role-policy --role-name "${ROLE_NAME}" --policy-arn "${POLICY_ARN}" 2>/dev/null || true
  aws iam delete-role --role-name "${ROLE_NAME}"
else
  echo "IAM role ${ROLE_NAME} not found, skipping."
fi

# --- Local build artifacts ---------------------------------------------------
if [ -d "${SCRIPT_DIR}/build" ]; then
  echo "Removing local build directory..."
  rm -rf "${SCRIPT_DIR}/build"
fi

echo ""
echo "Teardown complete."
