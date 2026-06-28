package com.wallmart.payment;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;

@SpringBootApplication
public class PaymentServiceApplication {

  private static final Logger log = LoggerFactory.getLogger(PaymentServiceApplication.class);

  public static void main(String[] args) {
    SpringApplication.run(PaymentServiceApplication.class, args);
  }

  @EventListener(ApplicationReadyEvent.class)
  void onReady() {
    log.info("event=service.started service=payment-service");
  }
}
