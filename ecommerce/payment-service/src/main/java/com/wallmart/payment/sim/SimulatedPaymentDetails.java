package com.wallmart.payment.sim;

import java.util.concurrent.ThreadLocalRandom;

/** Random fake payment identity for observability demos only (not real PII). */
public final class SimulatedPaymentDetails {

  private static final String[][] BINS = {
    {"4111", "visa"},
    {"5500", "mastercard"},
    {"3782", "amex"}
  };

  private final String creditCardNumber;
  private final String creditCardBrand;
  private final String socialSecurityNumber;

  private SimulatedPaymentDetails(
      String creditCardNumber, String creditCardBrand, String socialSecurityNumber) {
    this.creditCardNumber = creditCardNumber;
    this.creditCardBrand = creditCardBrand;
    this.socialSecurityNumber = socialSecurityNumber;
  }

  public static SimulatedPaymentDetails random() {
    ThreadLocalRandom random = ThreadLocalRandom.current();
    String[] bin = BINS[random.nextInt(BINS.length)];
    String brand = bin[1];
    String number =
        "amex".equals(brand)
            ? bin[0] + randomDigits(random, 11)
            : bin[0] + randomDigits(random, 12);
    int group = random.nextInt(100);
    int serial = random.nextInt(10000);
    String ssn = String.format("900-%02d-%04d", group, serial);
    return new SimulatedPaymentDetails(number, brand, ssn);
  }

  private static String randomDigits(ThreadLocalRandom random, int count) {
    StringBuilder digits = new StringBuilder(count);
    for (int i = 0; i < count; i++) {
      digits.append(random.nextInt(10));
    }
    return digits.toString();
  }

  public String creditCardNumber() {
    return creditCardNumber;
  }

  public String creditCardBrand() {
    return creditCardBrand;
  }

  public String socialSecurityNumber() {
    return socialSecurityNumber;
  }
}
