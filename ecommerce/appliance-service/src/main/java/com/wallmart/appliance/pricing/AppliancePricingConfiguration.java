package com.wallmart.appliance.pricing;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestClient;

@Configuration
public class AppliancePricingConfiguration {

  @Bean
  AppliancePricingApi appliancePricingApi(
      @Value("${wallmart.appliance-pricing-lambda-url:}") String lambdaUrl) {
    if (lambdaUrl.isBlank()) {
      return sku -> {
        throw new AppliancePricingException(
            503, "Dynamic pricing is enabled but APPLIANCE_PRICING_LAMBDA_URL is not configured");
      };
    }
    RestClient client = RestClient.builder().baseUrl(lambdaUrl).build();
    return new HttpAppliancePricingApi(client);
  }
}
