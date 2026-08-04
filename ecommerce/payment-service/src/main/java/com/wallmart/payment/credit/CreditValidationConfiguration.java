package com.wallmart.payment.credit;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestClient;

@Configuration
public class CreditValidationConfiguration {

  @Bean
  CreditValidationApi creditValidationApi(
      @Value("${wallmart.credit-validation-lambda-url:}") String lambdaUrl) {
    if (lambdaUrl.isBlank()) {
      return (amount, cardLast4) -> {
        throw new CreditValidationException(
            503, "Credit validation is enabled but CREDIT_VALIDATION_LAMBDA_URL is not configured");
      };
    }
    RestClient client = RestClient.builder().baseUrl(lambdaUrl).build();
    return new HttpCreditValidationApi(client);
  }
}
