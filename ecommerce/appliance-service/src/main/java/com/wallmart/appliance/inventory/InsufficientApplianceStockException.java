package com.wallmart.appliance.inventory;

public class InsufficientApplianceStockException extends RuntimeException {

  public InsufficientApplianceStockException(String message) {
    super(message);
  }
}
