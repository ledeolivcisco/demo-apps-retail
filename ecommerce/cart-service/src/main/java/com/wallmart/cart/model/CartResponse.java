package com.wallmart.cart.model;

import java.math.BigDecimal;
import java.util.List;

public record CartResponse(List<CartLineItem> lineItems, BigDecimal total) {
}
