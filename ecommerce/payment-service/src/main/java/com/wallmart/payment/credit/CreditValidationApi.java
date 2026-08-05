package com.wallmart.payment.credit;

import java.math.BigDecimal;

public interface CreditValidationApi {

  CreditValidationResult validate(BigDecimal amount, String cardLast4);
}
