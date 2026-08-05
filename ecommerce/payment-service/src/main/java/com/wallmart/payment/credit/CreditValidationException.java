package com.wallmart.payment.credit;

public class CreditValidationException extends RuntimeException {

  private final int httpStatus;

  public CreditValidationException(int httpStatus, String message) {
    super(message);
    this.httpStatus = httpStatus;
  }

  public CreditValidationException(int httpStatus, String message, Throwable cause) {
    super(message, cause);
    this.httpStatus = httpStatus;
  }

  public int httpStatus() {
    return httpStatus;
  }
}
