package com.wallmart.cart.checkout.remote;

import com.wallmart.cart.checkout.CheckoutPaymentException;
import com.wallmart.cart.checkout.PayResult;
import com.wallmart.cart.checkout.PaymentConfirmationApi;
import java.math.BigDecimal;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

public final class HttpPaymentConfirmationApi implements PaymentConfirmationApi {

  private static final Logger log = LoggerFactory.getLogger(HttpPaymentConfirmationApi.class);

  private final RestClient client;

  public HttpPaymentConfirmationApi(RestClient client) {
    this.client = client;
  }

  @Override
  public PayResult confirm(BigDecimal amount) {
    log.info("event=checkout.payment.requested amount={}", amount);
    try {
      return client
          .post()
          .uri("/confirm-payment")
          .contentType(MediaType.APPLICATION_JSON)
          .body(new PayAmountBody(amount))
          .retrieve()
          .body(PayResult.class);
    } catch (RestClientResponseException e) {
      log.error(
          "event=checkout.payment.failed status={} amount={}",
          e.getStatusCode().value(),
          amount);
      throw new CheckoutPaymentException(
          "Payment confirmation failed: " + e.getStatusCode(), e);
    }
  }
}
