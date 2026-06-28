package com.wallmart.cart.web;

import java.math.BigDecimal;

/** JSON body for {@code POST /checkout} (same shape as payment-service {@code PayRequest}). */
public record CheckoutRequest(BigDecimal value) {}
