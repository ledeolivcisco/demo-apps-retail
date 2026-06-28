package com.wallmart.cart.web;

import static com.wallmart.cart.support.SessionTestSupport.withSession;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.wallmart.db.testsupport.AbstractSqlServerSpringBootTest;
import com.wallmart.cart.checkout.CheckoutInventoryConflictException;
import com.wallmart.cart.checkout.CheckoutPaymentException;
import com.wallmart.cart.checkout.PayResult;
import com.wallmart.cart.checkout.PaymentConfirmationApi;
import com.wallmart.cart.checkout.ProductInventoryApi;
import java.math.BigDecimal;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.annotation.DirtiesContext.ClassMode;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@DirtiesContext(classMode = ClassMode.AFTER_EACH_TEST_METHOD)
class CheckoutControllerApiTest extends AbstractSqlServerSpringBootTest {

  @Autowired private MockMvc mockMvc;

  @MockBean private ProductInventoryApi productInventoryApi;

  @MockBean private PaymentConfirmationApi paymentConfirmationApi;

  @Test
  @DisplayName("POST /checkout returns 400 when cart is empty")
  void checkout_emptyCart_returns400() throws Exception {
    mockMvc
        .perform(
            withSession(post("/checkout"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"value\":10.00}")
                .accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.message").value("Cart is empty"));
  }

  @Test
  @DisplayName("POST /checkout returns 400 when amount does not match cart total")
  void checkout_wrongAmount_returns400() throws Exception {
    mockMvc.perform(withSession(post("/addproduct/1"))).andExpect(status().isOk());

    mockMvc
        .perform(
            withSession(post("/checkout"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"value\":1.00}")
                .accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.message").exists());
  }

  @Test
  @DisplayName("POST /checkout deducts inventory, confirms payment, then clears cart")
  void checkout_success_callsDownstreamAndClearsCart() throws Exception {
    mockMvc.perform(withSession(post("/addproduct/2"))).andExpect(status().isOk());

    doNothing().when(productInventoryApi).deduct(anyList());
    when(paymentConfirmationApi.confirm(any(BigDecimal.class)))
        .thenReturn(new PayResult("success", "Payment successful"));

    mockMvc
        .perform(
            withSession(post("/checkout"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"value\":4.29}")
                .accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.status").value("success"))
        .andExpect(jsonPath("$.message").value("Payment successful"));

    InOrder order = inOrder(productInventoryApi, paymentConfirmationApi);
    order.verify(productInventoryApi).deduct(anyList());
    order.verify(paymentConfirmationApi).confirm(new BigDecimal("4.29"));

    mockMvc
        .perform(withSession(get("/getcart")).accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.lineItems").isEmpty());
  }

  @Test
  @DisplayName("POST /checkout returns 409 when inventory deduct fails")
  void checkout_inventoryConflict_returns409() throws Exception {
    mockMvc.perform(withSession(post("/addproduct/5"))).andExpect(status().isOk());

    doThrow(new CheckoutInventoryConflictException("Insufficient stock for product 5"))
        .when(productInventoryApi)
        .deduct(anyList());

    mockMvc
        .perform(
            withSession(post("/checkout"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"value\":6.99}")
                .accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isConflict())
        .andExpect(jsonPath("$.message").value("Insufficient stock for product 5"));

    verify(productInventoryApi).deduct(anyList());
    verify(paymentConfirmationApi, never()).confirm(any());
  }

  @Test
  @DisplayName("POST /checkout restores inventory when payment confirmation fails")
  void checkout_paymentFails_restoresInventory() throws Exception {
    mockMvc.perform(withSession(post("/addproduct/8"))).andExpect(status().isOk());

    doNothing().when(productInventoryApi).deduct(anyList());
    doNothing().when(productInventoryApi).restore(anyList());
    when(paymentConfirmationApi.confirm(any(BigDecimal.class)))
        .thenThrow(new CheckoutPaymentException("down", new RuntimeException("boom")));

    mockMvc
        .perform(
            withSession(post("/checkout"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"value\":1.29}")
                .accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isBadGateway());

    verify(productInventoryApi).deduct(anyList());
    verify(productInventoryApi).restore(anyList());
  }
}
