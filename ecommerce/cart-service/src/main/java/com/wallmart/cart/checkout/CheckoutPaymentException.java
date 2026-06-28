package com.wallmart.cart.checkout;

public class CheckoutPaymentException extends RuntimeException {

  public CheckoutPaymentException(String message, Throwable cause) {
    super(message, cause);
  }
}
