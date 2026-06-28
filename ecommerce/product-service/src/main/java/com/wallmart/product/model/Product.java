package com.wallmart.product.model;

import java.math.BigDecimal;

public record Product(
    String productId,
    String productDescription,
    BigDecimal productPrice,
    String productPicture,
    int stock) {}
