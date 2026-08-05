package com.wallmart.appliance.pricing;

import java.math.BigDecimal;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

public final class HttpAppliancePricingApi implements AppliancePricingApi {

  private static final Logger log = LoggerFactory.getLogger(HttpAppliancePricingApi.class);

  private final RestClient client;

  public HttpAppliancePricingApi(RestClient client) {
    this.client = client;
  }

  @Override
  public BigDecimal getPrice(String sku) {
    log.info("event=appliance.pricing.requested sku={}", sku);
    try {
      AppliancePricingResponse response =
          client
              .post()
              .contentType(MediaType.APPLICATION_JSON)
              .body(new AppliancePricingRequest(sku))
              .retrieve()
              .body(AppliancePricingResponse.class);
      if (response == null) {
        throw new AppliancePricingException(502, "Pricing service returned an empty response");
      }
      log.info(
          "event=appliance.pricing.completed requestId={} sku={} price={}",
          response.requestId(),
          response.sku(),
          response.price());
      return BigDecimal.valueOf(response.price());
    } catch (AppliancePricingException e) {
      throw e;
    } catch (RestClientException e) {
      log.error("event=appliance.pricing.failed sku={} reason={}", sku, e.getMessage());
      throw new AppliancePricingException(502, "Pricing service unavailable", e);
    }
  }
}
