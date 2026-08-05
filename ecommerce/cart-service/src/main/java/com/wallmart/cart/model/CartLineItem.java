package com.wallmart.cart.model;

import java.math.BigDecimal;

public record CartLineItem(
    String itemType,
    String itemId,
    String description,
    BigDecimal price,
    String picture,
    int quantity) {
}
