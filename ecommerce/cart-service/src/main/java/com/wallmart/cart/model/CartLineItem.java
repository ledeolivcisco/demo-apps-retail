package com.wallmart.cart.model;

import java.math.BigDecimal;

public record CartLineItem(
    String productId,
    String productDescription,
    BigDecimal productPrice,
    String productPicture,
    int quantity) {
}
