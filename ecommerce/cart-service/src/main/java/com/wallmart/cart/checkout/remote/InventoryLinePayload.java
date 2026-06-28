package com.wallmart.cart.checkout.remote;

/** JSON line for product-service {@code POST /internal/inventory/*}. */
public record InventoryLinePayload(String productId, int quantity) {}
