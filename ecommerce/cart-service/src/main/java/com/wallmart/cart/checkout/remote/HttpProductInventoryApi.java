package com.wallmart.cart.checkout.remote;

import com.wallmart.cart.checkout.CheckoutInventoryConflictException;
import com.wallmart.cart.checkout.ProductInventoryApi;
import com.wallmart.cart.model.CartLineItem;
import java.nio.charset.StandardCharsets;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

public final class HttpProductInventoryApi implements ProductInventoryApi {

  private static final Logger log = LoggerFactory.getLogger(HttpProductInventoryApi.class);

  private final RestClient client;

  public HttpProductInventoryApi(RestClient client) {
    this.client = client;
  }

  @Override
  public void deduct(List<CartLineItem> lines) {
    log.info("event=checkout.inventory.deduct.requested lineCount={}", lines.size());
    List<InventoryLinePayload> body =
        lines.stream()
            .map(l -> new InventoryLinePayload(l.productId(), l.quantity()))
            .toList();
    try {
      client
          .post()
          .uri("/internal/inventory/deduct")
          .contentType(MediaType.APPLICATION_JSON)
          .body(body)
          .retrieve()
          .toBodilessEntity();
    } catch (RestClientResponseException e) {
      if (e.getStatusCode() == HttpStatus.CONFLICT) {
        throw new CheckoutInventoryConflictException(readBody(e));
      }
      log.warn(
          "event=checkout.inventory.deduct.failed status={} lineCount={}",
          e.getStatusCode().value(),
          lines.size());
      throw new IllegalStateException(
          "Product inventory deduct failed: " + e.getStatusCode(), e);
    }
  }

  @Override
  public void restore(List<CartLineItem> lines) {
    List<InventoryLinePayload> body =
        lines.stream()
            .map(l -> new InventoryLinePayload(l.productId(), l.quantity()))
            .toList();
    try {
      client
          .post()
          .uri("/internal/inventory/restore")
          .contentType(MediaType.APPLICATION_JSON)
          .body(body)
          .retrieve()
          .toBodilessEntity();
    } catch (RestClientResponseException e) {
      log.error(
          "event=inventory.restore.failed status={} lineCount={}",
          e.getStatusCode().value(),
          lines.size());
      throw new IllegalStateException(
          "Product inventory restore failed: " + e.getStatusCode(), e);
    }
  }

  private static String readBody(RestClientResponseException e) {
    String raw = e.getResponseBodyAsString(StandardCharsets.UTF_8);
    return raw != null && !raw.isBlank() ? raw : "Insufficient stock";
  }
}
