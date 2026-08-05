package com.wallmart.cart.checkout;

import com.wallmart.cart.model.CartLineItem;
import com.wallmart.cart.model.ItemType;
import com.wallmart.cart.service.CartService;
import com.wallmart.session.SessionContext;
import com.wallmart.session.SessionRegistry;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class CheckoutService {

  private static final Logger log = LoggerFactory.getLogger(CheckoutService.class);
  private static final int MONEY_SCALE = 2;

  private final CartService cartService;
  private final ProductInventoryApi productInventoryApi;
  private final ApplianceInventoryApi applianceInventoryApi;
  private final PaymentConfirmationApi paymentConfirmationApi;
  private final SessionRegistry sessionRegistry;

  public CheckoutService(
      CartService cartService,
      ProductInventoryApi productInventoryApi,
      ApplianceInventoryApi applianceInventoryApi,
      PaymentConfirmationApi paymentConfirmationApi,
      SessionRegistry sessionRegistry) {
    this.cartService = cartService;
    this.productInventoryApi = productInventoryApi;
    this.applianceInventoryApi = applianceInventoryApi;
    this.paymentConfirmationApi = paymentConfirmationApi;
    this.sessionRegistry = sessionRegistry;
  }

  public PayResult checkout(BigDecimal clientAmount) {
    sessionRegistry.requireActive(SessionContext.require().sessionId());
    if (clientAmount == null) {
      log.warn("event=checkout.validation.failed reason=missing_amount");
      throw new BadCheckoutRequestException("Missing payment amount");
    }
    var cart = cartService.getCart();
    if (cart.lineItems().isEmpty()) {
      log.warn("event=checkout.validation.failed reason=empty_cart");
      throw new BadCheckoutRequestException("Cart is empty");
    }
    BigDecimal normalized = clientAmount.setScale(MONEY_SCALE, RoundingMode.HALF_UP);
    BigDecimal serverTotal = cart.total().setScale(MONEY_SCALE, RoundingMode.HALF_UP);
    if (normalized.compareTo(serverTotal) != 0) {
      log.warn(
          "event=checkout.validation.failed reason=amount_mismatch expected={} got={}",
          serverTotal,
          normalized);
      throw new BadCheckoutRequestException(
          "Amount does not match cart total (expected "
              + serverTotal
              + ", got "
              + normalized
              + ")");
    }
    List<CartLineItem> lines = List.copyOf(cart.lineItems());
    List<CartLineItem> productLines =
        lines.stream().filter(l -> ItemType.PRODUCT.name().equals(l.itemType())).toList();
    List<CartLineItem> applianceLines =
        lines.stream().filter(l -> ItemType.APPLIANCE.name().equals(l.itemType())).toList();
    BigDecimal applianceAmount =
        applianceLines.stream()
            .map(l -> l.price().multiply(BigDecimal.valueOf(l.quantity())))
            .reduce(BigDecimal.ZERO, BigDecimal::add)
            .setScale(MONEY_SCALE, RoundingMode.HALF_UP);
    if (applianceLines.isEmpty()) {
      applianceAmount = null;
    }
    log.info(
        "event=checkout.started lineCount={} cartTotal={} clientAmount={}",
        lines.size(),
        serverTotal,
        normalized);

    // Track which groups were actually deducted so a failure partway through (e.g. products
    // deducted but appliance stock insufficient) only restores what was actually taken.
    boolean productsDeducted = false;
    boolean appliancesDeducted = false;
    try {
      if (!productLines.isEmpty()) {
        productInventoryApi.deduct(productLines);
        productsDeducted = true;
      }
      if (!applianceLines.isEmpty()) {
        applianceInventoryApi.deduct(applianceLines);
        appliancesDeducted = true;
      }
      PayResult result = paymentConfirmationApi.confirm(normalized, applianceAmount);
      cartService.clearCart();
      log.info(
          "event=checkout.completed cartTotal={} paymentStatus={}",
          serverTotal,
          result.status());
      return result;
    } catch (RuntimeException e) {
      log.warn(
          "event=checkout.compensating.inventory.restore lineCount={} reason={}",
          lines.size(),
          e.getClass().getSimpleName());
      if (productsDeducted) {
        productInventoryApi.restore(productLines);
      }
      if (appliancesDeducted) {
        applianceInventoryApi.restore(applianceLines);
      }
      log.error("event=checkout.failed reason={}", e.getMessage());
      throw e;
    }
  }
}
