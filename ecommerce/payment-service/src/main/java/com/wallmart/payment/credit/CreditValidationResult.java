package com.wallmart.payment.credit;

public record CreditValidationResult(String status, String reason, String requestId) {

  public boolean approved() {
    return "approved".equalsIgnoreCase(status);
  }
}
