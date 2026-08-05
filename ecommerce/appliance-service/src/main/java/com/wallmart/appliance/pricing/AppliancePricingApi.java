package com.wallmart.appliance.pricing;

import java.math.BigDecimal;

public interface AppliancePricingApi {

  BigDecimal getPrice(String sku);
}
