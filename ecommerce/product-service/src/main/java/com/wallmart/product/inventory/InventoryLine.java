package com.wallmart.product.inventory;

/**
 * JSON line for {@code POST /internal/inventory/deduct} and {@code POST /internal/inventory/restore}.
 */
public record InventoryLine(String productId, int quantity) {}
