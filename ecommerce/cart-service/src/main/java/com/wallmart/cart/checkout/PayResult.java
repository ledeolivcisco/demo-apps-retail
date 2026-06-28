package com.wallmart.cart.checkout;

/** Same JSON shape as payment-service {@code PayResponse} for the SPA. */
public record PayResult(String status, String message) {}
