package com.wallmart.cart.service;

import com.wallmart.cart.catalog.JdbcApplianceLookup;
import com.wallmart.cart.catalog.JdbcProductLookup;
import com.wallmart.cart.model.Appliance;
import com.wallmart.cart.model.CartResponse;
import com.wallmart.cart.model.ItemType;
import com.wallmart.cart.model.Product;
import com.wallmart.cart.repository.JdbcCartRepository;
import com.wallmart.session.SessionContext;
import com.wallmart.session.SessionRegistry;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class CartService {

  private static final Logger log = LoggerFactory.getLogger(CartService.class);

  private final JdbcProductLookup productLookup;
  private final JdbcApplianceLookup applianceLookup;
  private final JdbcCartRepository cartRepository;
  private final SessionRegistry sessionRegistry;

  public CartService(
      JdbcProductLookup productLookup,
      JdbcApplianceLookup applianceLookup,
      JdbcCartRepository cartRepository,
      SessionRegistry sessionRegistry) {
    this.productLookup = productLookup;
    this.applianceLookup = applianceLookup;
    this.cartRepository = cartRepository;
    this.sessionRegistry = sessionRegistry;
  }

  public Optional<String> addProduct(String productId) {
    sessionRegistry.requireActive(currentSessionId());
    Optional<Product> product = productLookup.findById(productId);
    if (product.isEmpty()) {
      log.warn("event=cart.item.unknown itemType=PRODUCT itemId={}", productId);
      return Optional.of("Unknown product id: " + productId);
    }
    cartRepository.addItem(currentSessionId(), ItemType.PRODUCT.name(), productId);
    log.info("event=cart.item.added itemType=PRODUCT itemId={}", productId);
    return Optional.empty();
  }

  public Optional<String> addAppliance(String applianceId) {
    sessionRegistry.requireActive(currentSessionId());
    Optional<Appliance> appliance = applianceLookup.findById(applianceId);
    if (appliance.isEmpty()) {
      log.warn("event=cart.item.unknown itemType=APPLIANCE itemId={}", applianceId);
      return Optional.of("Unknown appliance id: " + applianceId);
    }
    cartRepository.addItem(currentSessionId(), ItemType.APPLIANCE.name(), applianceId);
    log.info("event=cart.item.added itemType=APPLIANCE itemId={}", applianceId);
    return Optional.empty();
  }

  public CartResponse getCart() {
    sessionRegistry.requireActive(currentSessionId());
    CartResponse cart = cartRepository.getCart(currentSessionId());
    log.info(
        "event=cart.viewed lineCount={} cartTotal={}",
        cart.lineItems().size(),
        cart.total());
    return cart;
  }

  public void clearCart() {
    sessionRegistry.requireActive(currentSessionId());
    cartRepository.clearCart(currentSessionId());
    log.info("event=cart.cleared sessionId={}", currentSessionId());
  }

  private static String currentSessionId() {
    return SessionContext.require().sessionId();
  }
}
