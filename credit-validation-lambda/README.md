# credit-validation-lambda

A standalone AWS Lambda function that simulates credit validation for demo
purposes. It does not call any real credit bureau or payment processor — it
just randomly approves or declines each request, so it's useful for
generating realistic-looking approve/decline traffic in observability demos.

Publicly reachable over HTTPS via an **API Gateway HTTP API** in front of
the Lambda. The endpoint has **no authentication** — intended for demo use
only, not production.

> Note: Lambda Function URLs (`lambda:CreateFunctionUrlConfig`) are blocked
> by an AWS Organizations SCP on this account, so API Gateway is used
> instead to expose the public endpoint. Neither option gives you a fixed/
> static IP address — both resolve to AWS-managed shared IP ranges. If you
> need a real static IP, that requires the Lambda to run in a VPC behind a
> NAT Gateway with an Elastic IP (extra cost and complexity), which was
> intentionally not chosen for this demo.

Instrumented with the **Splunk OpenTelemetry Lambda layer** — every invocation
sends traces and metrics to Splunk Observability Cloud, no code changes
needed (see [Observability](#observability) below).

## Files

- `lambda_function.py` — the handler.
- `deploy.sh` — creates/updates everything via the AWS CLI (IAM role, function, API Gateway, Splunk instrumentation layer).
- `destroy.sh` — deletes everything created by `deploy.sh`.
- `test.sh` — fires a few sample requests at the deployed endpoint.
- `.env.example` — template for the Splunk Observability Cloud credentials `deploy.sh` needs. Copy to `.env` (gitignored) and fill in real values before deploying.

## Request / response

Request (`POST` with a JSON body — fields are optional and just echoed back):

```json
{ "amount": 129.99, "cardLast4": "1111" }
```

Response:

```json
{
  "requestId": "5f1c2e2a-...-...",
  "status": "approved",
  "reason": "Approved",
  "timestamp": "2026-08-04T15:24:00Z",
  "amount": 129.99,
  "cardLast4": "1111"
}
```

`status` is `"approved"` or `"declined"`. The approval rate defaults to 80%
and is controlled by the `APPROVAL_RATE` environment variable on the
function (e.g. `0.5` for 50/50).

## Deploy

Requires the AWS CLI already configured with credentials (`aws sts
get-caller-identity` should work), plus `zip` and `jq` installed locally.

```bash
cp .env.example .env   # fill in SPLUNK_ACCESS_TOKEN (and SPLUNK_REALM if not us1)
./deploy.sh
```

This is idempotent — re-run it any time you change `lambda_function.py` to
push a new version. It prints the public API endpoint at the end.

## Observability

The function is instrumented with the [Splunk OpenTelemetry Lambda layer](https://github.com/signalfx/splunk-otel-lambda)
(all-in-one layer: bundled Collector + Python auto-instrumentation, no
dependencies added to the deployment zip). `deploy.sh` attaches the layer and
sets these environment variables on the function:

| Variable | Purpose |
| --- | --- |
| `AWS_LAMBDA_EXEC_WRAPPER` | `/opt/otel-instrument` — activates auto-instrumentation for Python |
| `SPLUNK_REALM` / `SPLUNK_ACCESS_TOKEN` | From your local `.env` — where to send telemetry |
| `OTEL_SERVICE_NAME` | Service name shown in APM (default `credit-validation-lambda`) |
| `OTEL_RESOURCE_ATTRIBUTES` | `deployment.environment=...` (default `credit-validation-lambda`) |
| `OTEL_LOGS_EXPORTER` | `none` — this function doesn't emit OTel logs, avoids harmless `Failed to export logs batch` errors in CloudWatch |

Every invocation (via the API Gateway endpoint or a direct `aws lambda
invoke`) produces a trace and Lambda platform metrics (invocations, duration,
errors, cold starts) visible in Splunk APM / Infrastructure > Lambda within
Splunk Observability Cloud.

The layer version pinned in `deploy.sh` (`SPLUNK_LAMBDA_LAYER_ARN`) is for
`us-east-1`/x86_64. For another region or Graviton/ARM64, look up the current
ARN in the [Splunk layer ARN list](https://github.com/signalfx/lambda-layer-versions/blob/main/splunk-apm/splunk-arns.md)
and override it, e.g. `SPLUNK_LAMBDA_LAYER_ARN=arn:... ./deploy.sh`.

## Try it

```bash
API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='credit-validation-api'].ApiId" --output text)
API_URL=$(aws apigatewayv2 get-api --api-id "$API_ID" --query 'ApiEndpoint' --output text)

curl -s -X POST "$API_URL" \
  -H 'content-type: application/json' \
  -d '{"amount": 129.99, "cardLast4": "1111"}' | python3 -m json.tool
```

## Tear down

```bash
./destroy.sh
```

Deletes the API Gateway, Lambda function, and IAM role created by `deploy.sh`. Safe to re-run.
