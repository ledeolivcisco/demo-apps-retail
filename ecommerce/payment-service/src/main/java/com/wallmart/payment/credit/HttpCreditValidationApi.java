package com.wallmart.payment.credit;

import java.math.BigDecimal;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

public final class HttpCreditValidationApi implements CreditValidationApi {

  private static final Logger log = LoggerFactory.getLogger(HttpCreditValidationApi.class);

  private final RestClient client;

  public HttpCreditValidationApi(RestClient client) {
    this.client = client;
  }

  @Override
  public CreditValidationResult validate(BigDecimal amount, String cardLast4) {
    log.info("event=credit.validation.requested amount={} cardLast4={}", amount, cardLast4);
    try {
      CreditValidationResponse response =
          client
              .post()
              .contentType(MediaType.APPLICATION_JSON)
              .body(new CreditValidationRequest(amount, cardLast4))
              .retrieve()
              .body(CreditValidationResponse.class);
      if (response == null || response.status() == null) {
        throw new CreditValidationException(
            502, "Credit validation returned an empty response");
      }
      log.info(
          "event=credit.validation.completed requestId={} status={} reason={}",
          response.requestId(),
          response.status(),
          response.reason());
      return new CreditValidationResult(
          response.status(), response.reason(), response.requestId());
    } catch (CreditValidationException e) {
      throw e;
    } catch (RestClientException e) {
      log.error("event=credit.validation.failed amount={} reason={}", amount, e.getMessage());
      throw new CreditValidationException(
          502, "Credit validation service unavailable", e);
    }
  }
}
