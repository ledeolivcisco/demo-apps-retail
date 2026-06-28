package com.wallmart.cart.web;

import com.wallmart.cart.checkout.BadCheckoutRequestException;
import com.wallmart.cart.checkout.CheckoutInventoryConflictException;
import com.wallmart.cart.checkout.CheckoutPaymentException;
import com.wallmart.cart.checkout.CheckoutService;
import com.wallmart.cart.model.CartResponse;
import com.wallmart.cart.service.CartService;
import java.util.Map;
import java.util.Optional;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class CartController {

  private final CartService cartService;
  private final CheckoutService checkoutService;

  public CartController(CartService cartService, CheckoutService checkoutService) {
    this.cartService = cartService;
    this.checkoutService = checkoutService;
  }

  @RequestMapping(value = "/addproduct/{id}", method = {RequestMethod.GET, RequestMethod.POST})
  public ResponseEntity<?> addProduct(@PathVariable("id") String id) {
    Optional<String> error = cartService.addProduct(id);
    if (error.isPresent()) {
      return ResponseEntity.status(HttpStatus.NOT_FOUND)
          .body(Map.of("message", error.get()));
    }
    return ResponseEntity.ok(Map.of("message", "Product added to cart"));
  }

  @GetMapping("/getcart")
  public ResponseEntity<CartResponse> getCart() {
    return ResponseEntity.ok(cartService.getCart());
  }

  @DeleteMapping("/clearcart")
  public ResponseEntity<Map<String, String>> clearCart() {
    cartService.clearCart();
    return ResponseEntity.ok(Map.of("message", "Cart cleared"));
  }

  /**
   * Checkout: deducts inventory via product-service, confirms payment via payment-service, then
   * clears the cart. Restores inventory if payment confirmation fails.
   */
  @PostMapping("/checkout")
  public ResponseEntity<?> checkout(@RequestBody CheckoutRequest request) {
    try {
      return ResponseEntity.ok(checkoutService.checkout(request.value()));
    } catch (BadCheckoutRequestException e) {
      return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
    } catch (CheckoutInventoryConflictException e) {
      return ResponseEntity.status(HttpStatus.CONFLICT).body(Map.of("message", e.getMessage()));
    } catch (CheckoutPaymentException e) {
      return ResponseEntity.status(HttpStatus.BAD_GATEWAY)
          .body(Map.of("message", e.getMessage()));
    }
  }
}
