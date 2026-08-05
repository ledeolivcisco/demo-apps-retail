package com.wallmart.cart.checkout.remote;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.wallmart.cart.checkout.ApplianceInventoryApi;
import com.wallmart.cart.checkout.CheckoutInventoryConflictException;
import com.wallmart.cart.model.CartLineItem;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.web.client.RestClient;

/**
 * Calls appliance-service's GraphQL mutations for stock changes. Unlike product-service (REST,
 * 409 on conflict), GraphQL errors always come back as HTTP 200 with an {@code errors} array, so
 * conflicts are detected by inspecting the response body rather than the HTTP status.
 */
public final class GraphQlApplianceInventoryApi implements ApplianceInventoryApi {

  private static final Logger log = LoggerFactory.getLogger(GraphQlApplianceInventoryApi.class);

  private static final String DEDUCT_MUTATION =
      """
      mutation($id: ID!, $qty: Int!) {
        deductApplianceStock(applianceId: $id, quantity: $qty) { applianceId stock }
      }
      """;

  private static final String RESTORE_MUTATION =
      """
      mutation($id: ID!, $qty: Int!) {
        restoreApplianceStock(applianceId: $id, quantity: $qty) { applianceId stock }
      }
      """;

  private final RestClient client;

  public GraphQlApplianceInventoryApi(RestClient client) {
    this.client = client;
  }

  @Override
  public void deduct(List<CartLineItem> lines) {
    log.info("event=checkout.appliance-inventory.deduct.requested lineCount={}", lines.size());
    for (CartLineItem line : lines) {
      GraphQlResponse response = execute(DEDUCT_MUTATION, line.itemId(), line.quantity());
      if (response.hasErrors()) {
        String message = response.firstErrorMessage();
        log.warn(
            "event=checkout.appliance-inventory.deduct.failed applianceId={} reason={}",
            line.itemId(),
            message);
        // The only expected mutation failure in normal operation is insufficient stock, so treat
        // any GraphQL error here as a checkout conflict (mirrors the REST 409 handling).
        throw new CheckoutInventoryConflictException(message);
      }
    }
  }

  @Override
  public void restore(List<CartLineItem> lines) {
    for (CartLineItem line : lines) {
      GraphQlResponse response = execute(RESTORE_MUTATION, line.itemId(), line.quantity());
      if (response.hasErrors()) {
        String message = response.firstErrorMessage();
        log.error(
            "event=appliance-inventory.restore.failed applianceId={} reason={}",
            line.itemId(),
            message);
        throw new IllegalStateException("Appliance inventory restore failed: " + message);
      }
    }
  }

  private GraphQlResponse execute(String query, String applianceId, int quantity) {
    GraphQlRequest request = new GraphQlRequest(query, Map.of("id", applianceId, "qty", quantity));
    GraphQlResponse response =
        client
            .post()
            .uri("/graphql")
            .contentType(MediaType.APPLICATION_JSON)
            .body(request)
            .retrieve()
            .body(GraphQlResponse.class);
    return response != null ? response : new GraphQlResponse(null, null);
  }

  private record GraphQlRequest(String query, Map<String, Object> variables) {}

  // GraphQL error objects also carry "locations", "path" and "extensions"; ignore anything
  // beyond the message since that's all the caller needs to classify the failure.
  @JsonIgnoreProperties(ignoreUnknown = true)
  private record GraphQlErrorPayload(String message) {}

  @JsonIgnoreProperties(ignoreUnknown = true)
  private record GraphQlResponse(Map<String, Object> data, List<GraphQlErrorPayload> errors) {

    boolean hasErrors() {
      return errors != null && !errors.isEmpty();
    }

    String firstErrorMessage() {
      return hasErrors() ? errors.get(0).message() : "Unknown appliance inventory error";
    }
  }
}
