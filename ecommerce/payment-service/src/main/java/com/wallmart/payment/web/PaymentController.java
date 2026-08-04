package com.wallmart.payment.web;

import com.wallmart.payment.credit.CreditValidationApi;
import com.wallmart.payment.credit.CreditValidationException;
import com.wallmart.payment.credit.CreditValidationResult;
import com.wallmart.payment.repository.PaymentTransactionRepository;
import com.wallmart.payment.sim.SimulatedPaymentDetails;
import com.wallmart.session.SessionContext;
import com.wallmart.session.SessionRegistry;
import java.math.BigDecimal;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class PaymentController {

  private static final Logger log = LoggerFactory.getLogger(PaymentController.class);

  private final SessionRegistry sessionRegistry;
  private final PaymentTransactionRepository paymentTransactionRepository;
  private final CreditValidationApi creditValidationApi;
  private final boolean validateCredit;

  public PaymentController(
      SessionRegistry sessionRegistry,
      PaymentTransactionRepository paymentTransactionRepository,
      CreditValidationApi creditValidationApi,
      @Value("${wallmart.validate-credit:false}") boolean validateCredit) {
    this.sessionRegistry = sessionRegistry;
    this.paymentTransactionRepository = paymentTransactionRepository;
    this.creditValidationApi = creditValidationApi;
    this.validateCredit = validateCredit;
  }

  @PostMapping("/pay")
  public ResponseEntity<PayResponse> pay(@RequestBody PayRequest request) {
    SimulatedPaymentDetails pii = SimulatedPaymentDetails.random();
    PayResponse response = confirmPaymentInternal(request, pii);
    logPaymentConfirmed(request, response, pii);
    return ResponseEntity.ok(response);
  }

  @PostMapping("/confirm-payment")
  public ResponseEntity<PayResponse> confirmPayment(@RequestBody PayRequest request) {
    SimulatedPaymentDetails pii = SimulatedPaymentDetails.random();
    PayResponse response = confirmPaymentInternal(request, pii);
    var session = SessionContext.require();
    logPaymentConfirmed(request, response, pii);
    paymentTransactionRepository.save(
        session.sessionId(),
        session.username(),
        request.value(),
        response.status(),
        response.message());
    log.info(
        "event=payment.transaction.saved simulated=true amount={} creditCardNumber={} ssn={} sessionId={}",
        request.value(),
        pii.creditCardNumber(),
        pii.socialSecurityNumber(),
        session.sessionId());
    sessionRegistry.close(session.sessionId());
    return ResponseEntity.ok(response);
  }

  private PayResponse confirmPaymentInternal(PayRequest request, SimulatedPaymentDetails pii) {
    validateCreditIfRequired(request, pii);
    return new PayResponse("success", "Payment successful");
  }

  private void validateCreditIfRequired(PayRequest request, SimulatedPaymentDetails pii) {
    if (!validateCredit) {
      return;
    }
    BigDecimal applianceAmount = request.applianceAmount();
    if (applianceAmount == null || applianceAmount.compareTo(BigDecimal.ZERO) <= 0) {
      return;
    }
    CreditValidationResult result =
        creditValidationApi.validate(applianceAmount, pii.cardLast4());
    if (!result.approved()) {
      String reason =
          result.reason() != null && !result.reason().isBlank()
              ? result.reason()
              : "Credit declined";
      throw new CreditValidationException(402, reason);
    }
  }

  private static void logPaymentConfirmed(
      PayRequest request, PayResponse response, SimulatedPaymentDetails pii) {
    log.info(
        "event=payment.confirmed simulated=true amount={} status={} creditCardNumber={} creditCardBrand={} ssn={}",
        request.value(),
        response.status(),
        pii.creditCardNumber(),
        pii.creditCardBrand(),
        pii.socialSecurityNumber());
  }
}
