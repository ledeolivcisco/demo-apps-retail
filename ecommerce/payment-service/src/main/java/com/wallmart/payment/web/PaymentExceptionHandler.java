package com.wallmart.payment.web;

import com.wallmart.payment.credit.CreditValidationException;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class PaymentExceptionHandler {

  @ExceptionHandler(CreditValidationException.class)
  public ResponseEntity<PayResponse> handleCreditValidation(CreditValidationException e) {
    String status = e.httpStatus() == 402 ? "declined" : "failed";
    return ResponseEntity.status(e.httpStatus()).body(new PayResponse(status, e.getMessage()));
  }
}
