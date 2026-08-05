package com.wallmart.cart.model;

import java.math.BigDecimal;

public record Appliance(
    String applianceId,
    String applianceDescription,
    BigDecimal appliancePrice,
    String appliancePicture) {
}
