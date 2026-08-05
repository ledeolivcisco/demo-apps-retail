package com.wallmart.appliance.model;

import java.math.BigDecimal;

public record Appliance(
    String applianceId,
    ApplianceType applianceType,
    String applianceDescription,
    BigDecimal appliancePrice,
    String appliancePicture,
    int stock) {}
