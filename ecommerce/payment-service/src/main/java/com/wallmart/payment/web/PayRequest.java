package com.wallmart.payment.web;

import java.math.BigDecimal;

/**
 * JSON body for {@code POST /pay}. Field name is {@code value} (the payment amount).
 * {@code applianceAmount} is the appliance subtotal; when present and credit validation
 * is enabled, only that portion is sent to the credit-validation lambda.
 */
public record PayRequest(BigDecimal value, BigDecimal applianceAmount) {
}
