package com.wallmart.payment.web;

import java.math.BigDecimal;

/**
 * JSON body for {@code POST /pay}. Field name is {@code value} (the payment amount).
 */
public record PayRequest(BigDecimal value) {
}
