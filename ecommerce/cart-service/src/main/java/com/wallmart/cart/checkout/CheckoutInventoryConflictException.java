package com.wallmart.cart.checkout;

public class CheckoutInventoryConflictException extends RuntimeException {

  public CheckoutInventoryConflictException(String message) {
    super(message);
  }
}
