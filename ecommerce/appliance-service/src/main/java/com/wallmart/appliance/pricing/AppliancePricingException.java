package com.wallmart.appliance.pricing;

public class AppliancePricingException extends RuntimeException {

  private final int httpStatus;

  public AppliancePricingException(int httpStatus, String message) {
    super(message);
    this.httpStatus = httpStatus;
  }

  public AppliancePricingException(int httpStatus, String message, Throwable cause) {
    super(message, cause);
    this.httpStatus = httpStatus;
  }

  public int httpStatus() {
    return httpStatus;
  }
}
