package com.wallmart.cart.checkout;

public class BadCheckoutRequestException extends RuntimeException {

  public BadCheckoutRequestException(String message) {
    super(message);
  }
}
