package com.wallmart.payment.web;

import static com.wallmart.payment.support.SessionTestSupport.withSession;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.wallmart.db.testsupport.AbstractSqlServerSpringBootTest;
import com.wallmart.payment.credit.CreditValidationApi;
import com.wallmart.payment.credit.CreditValidationResult;
import java.math.BigDecimal;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = "wallmart.validate-credit=true")
class PaymentControllerCreditValidationTest extends AbstractSqlServerSpringBootTest {

  @Autowired private MockMvc mockMvc;

  @MockBean private CreditValidationApi creditValidationApi;

  @Test
  @DisplayName("POST /confirm-payment skips credit validation when applianceAmount is absent")
  void confirmPayment_noApplianceAmount_skipsLambda() throws Exception {
    mockMvc
        .perform(
            withSession(post("/confirm-payment"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"value\":10.00}")
                .accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.status").value("success"));

    verify(creditValidationApi, never()).validate(any(), anyString());
  }

  @Test
  @DisplayName("POST /confirm-payment calls credit validation for appliance purchases when approved")
  void confirmPayment_applianceApproved() throws Exception {
    when(creditValidationApi.validate(eq(new BigDecimal("149.99")), anyString()))
        .thenReturn(new CreditValidationResult("approved", "Approved", "req-1"));

    mockMvc
        .perform(
            withSession(post("/confirm-payment"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"value\":149.99,\"applianceAmount\":149.99}")
                .accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.status").value("success"));

    verify(creditValidationApi).validate(eq(new BigDecimal("149.99")), anyString());
  }

  @Test
  @DisplayName("POST /confirm-payment returns 402 when credit validation declines")
  void confirmPayment_applianceDeclined() throws Exception {
    when(creditValidationApi.validate(eq(new BigDecimal("149.99")), anyString()))
        .thenReturn(
            new CreditValidationResult("declined", "Credit score below threshold", "req-2"));

    mockMvc
        .perform(
            withSession(post("/confirm-payment"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"value\":149.99,\"applianceAmount\":149.99}")
                .accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isPaymentRequired())
        .andExpect(jsonPath("$.status").value("declined"))
        .andExpect(jsonPath("$.message").value("Credit score below threshold"));
  }
}
