package com.wallmart.cart.checkout;

import java.math.BigDecimal;

public interface PaymentConfirmationApi {

  PayResult confirm(BigDecimal amount);
}
