package com.wallmart.payment.credit;

import java.math.BigDecimal;

record CreditValidationResponse(
    String requestId, String status, String reason, BigDecimal amount, String cardLast4) {}
