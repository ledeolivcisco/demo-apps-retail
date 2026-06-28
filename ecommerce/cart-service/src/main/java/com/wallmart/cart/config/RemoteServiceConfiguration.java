package com.wallmart.cart.config;

import com.wallmart.cart.checkout.PaymentConfirmationApi;
import com.wallmart.cart.checkout.ProductInventoryApi;
import com.wallmart.cart.checkout.remote.HttpPaymentConfirmationApi;
import com.wallmart.cart.checkout.remote.HttpProductInventoryApi;
import com.wallmart.session.SessionPropagationInterceptor;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestClient;

@Configuration
public class RemoteServiceConfiguration {

  @Bean
  @Qualifier("product")
  RestClient productRestClient(
      @Value("${wallmart.product-service-base-url:http://127.0.0.1:8081}") String baseUrl,
      SessionPropagationInterceptor sessionPropagationInterceptor) {
    return RestClient.builder()
        .baseUrl(baseUrl)
        .requestInterceptor(sessionPropagationInterceptor)
        .build();
  }

  @Bean
  @Qualifier("payment")
  RestClient paymentRestClient(
      @Value("${wallmart.payment-service-base-url:http://127.0.0.1:8083}") String baseUrl,
      SessionPropagationInterceptor sessionPropagationInterceptor) {
    return RestClient.builder()
        .baseUrl(baseUrl)
        .requestInterceptor(sessionPropagationInterceptor)
        .build();
  }

  @Bean
  ProductInventoryApi productInventoryApi(@Qualifier("product") RestClient client) {
    return new HttpProductInventoryApi(client);
  }

  @Bean
  PaymentConfirmationApi paymentConfirmationApi(@Qualifier("payment") RestClient client) {
    return new HttpPaymentConfirmationApi(client);
  }
}
