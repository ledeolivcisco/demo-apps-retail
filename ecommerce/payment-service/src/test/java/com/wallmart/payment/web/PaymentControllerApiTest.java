package com.wallmart.payment.web;

import static com.wallmart.payment.support.SessionTestSupport.withSession;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.wallmart.db.testsupport.AbstractSqlServerSpringBootTest;
import com.wallmart.payment.credit.CreditValidationApi;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
class PaymentControllerApiTest extends AbstractSqlServerSpringBootTest {

  @Autowired private MockMvc mockMvc;

  @MockBean private CreditValidationApi creditValidationApi;

  @Test
  @DisplayName("POST /pay returns 200 and success payload for JSON body with value")
  void pay_returnsSuccess() throws Exception {
    mockMvc
        .perform(
            withSession(post("/pay"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"value\":123.45}")
                .accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.status").value("success"))
        .andExpect(jsonPath("$.message").value("Payment successful"));

    verify(creditValidationApi, never()).validate(any(), anyString());
  }

  @Test
  @DisplayName("POST /confirm-payment returns same success payload as POST /pay")
  void confirmPayment_returnsSuccess() throws Exception {
    mockMvc
        .perform(
            withSession(post("/confirm-payment"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"value\":10.00}")
                .accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.status").value("success"))
        .andExpect(jsonPath("$.message").value("Payment successful"));
  }

  @Test
  @DisplayName("POST /pay still succeeds for zero amount (mock payment)")
  void pay_zeroValue_returnsSuccess() throws Exception {
    mockMvc
        .perform(
            withSession(post("/pay"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"value\":0}")
                .accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.status").value("success"));
  }
}
