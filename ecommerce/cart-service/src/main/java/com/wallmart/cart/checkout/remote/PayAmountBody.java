package com.wallmart.cart.checkout.remote;

import java.math.BigDecimal;

/** JSON body for payment-service {@code POST /confirm-payment}. */
public record PayAmountBody(BigDecimal value) {}
