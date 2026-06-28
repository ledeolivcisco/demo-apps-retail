package com.wallmart.payment.web;

import com.wallmart.payment.repository.PaymentTransactionRepository;
import com.wallmart.payment.sim.SimulatedPaymentDetails;
import com.wallmart.session.SessionContext;
import com.wallmart.session.SessionRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class PaymentController {

  private static final Logger log = LoggerFactory.getLogger(PaymentController.class);

  private final SessionRegistry sessionRegistry;
  private final PaymentTransactionRepository paymentTransactionRepository;

  public PaymentController(
      SessionRegistry sessionRegistry,
      PaymentTransactionRepository paymentTransactionRepository) {
    this.sessionRegistry = sessionRegistry;
    this.paymentTransactionRepository = paymentTransactionRepository;
  }

  @PostMapping("/pay")
  public ResponseEntity<PayResponse> pay(@RequestBody PayRequest request) {
    PayResponse response = confirmPaymentInternal(request);
    SimulatedPaymentDetails pii = SimulatedPaymentDetails.random();
    logPaymentConfirmed(request, response, pii);
    return ResponseEntity.ok(response);
  }

  @PostMapping("/confirm-payment")
  public ResponseEntity<PayResponse> confirmPayment(@RequestBody PayRequest request) {
    PayResponse response = confirmPaymentInternal(request);
    var session = SessionContext.require();
    SimulatedPaymentDetails pii = SimulatedPaymentDetails.random();
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

  private static PayResponse confirmPaymentInternal(PayRequest request) {
    return new PayResponse("success", "Payment successful");
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
