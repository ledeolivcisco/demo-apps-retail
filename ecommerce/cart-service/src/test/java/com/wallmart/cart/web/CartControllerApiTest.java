package com.wallmart.cart.web;

import static com.wallmart.cart.support.SessionTestSupport.OTHER_SESSION_ID;
import static com.wallmart.cart.support.SessionTestSupport.OTHER_USERNAME;
import static com.wallmart.cart.support.SessionTestSupport.withSession;
import static org.hamcrest.Matchers.closeTo;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.wallmart.db.testsupport.AbstractSqlServerSpringBootTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.annotation.DirtiesContext.ClassMode;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@DirtiesContext(classMode = ClassMode.AFTER_EACH_TEST_METHOD)
class CartControllerApiTest extends AbstractSqlServerSpringBootTest {

  @Autowired private MockMvc mockMvc;

  @Test
  @DisplayName("GET /getcart returns empty cart with zero total")
  void getCart_empty() throws Exception {
    mockMvc
        .perform(withSession(get("/getcart")).accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.lineItems", org.hamcrest.Matchers.hasSize(0)))
        .andExpect(jsonPath("$.total").value(0));
  }

  @Test
  @DisplayName("POST /addproduct/{id} adds line; GET /getcart returns item and total")
  void addProduct_post_then_getCart() throws Exception {
    mockMvc
        .perform(withSession(post("/addproduct/3")).accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.message").value("Product added to cart"));

    mockMvc
        .perform(withSession(get("/getcart")).accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.lineItems", org.hamcrest.Matchers.hasSize(1)))
        .andExpect(jsonPath("$.lineItems[0].productId").value("3"))
        .andExpect(jsonPath("$.lineItems[0].productDescription").value("Large Eggs 12 ct"))
        .andExpect(jsonPath("$.lineItems[0].quantity").value(1))
        .andExpect(jsonPath("$.total").value(closeTo(3.99, 0.001)));
  }

  @Test
  @DisplayName("GET /addproduct/{id} merges quantity for same product")
  void addProduct_get_mergesQuantity() throws Exception {
    mockMvc.perform(withSession(get("/addproduct/1"))).andExpect(status().isOk());
    mockMvc.perform(withSession(get("/addproduct/1"))).andExpect(status().isOk());

    mockMvc
        .perform(withSession(get("/getcart")).accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.lineItems", org.hamcrest.Matchers.hasSize(1)))
        .andExpect(jsonPath("$.lineItems[0].quantity").value(2))
        .andExpect(jsonPath("$.total").value(closeTo(6.98, 0.001)));
  }

  @Test
  @DisplayName("DELETE /clearcart empties the cart after items were added")
  void clearCart_removesAllLines() throws Exception {
    mockMvc.perform(withSession(post("/addproduct/2"))).andExpect(status().isOk());
    mockMvc
        .perform(withSession(get("/getcart")).accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.lineItems", org.hamcrest.Matchers.hasSize(1)));

    mockMvc
        .perform(withSession(delete("/clearcart")).accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.message").value("Cart cleared"));

    mockMvc
        .perform(withSession(get("/getcart")).accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.lineItems", org.hamcrest.Matchers.hasSize(0)))
        .andExpect(jsonPath("$.total").value(0));
  }

  @Test
  @DisplayName("GET and POST /addproduct/{id} return 404 for unknown id")
  void addProduct_unknownId_returns404() throws Exception {
    mockMvc
        .perform(withSession(get("/addproduct/unknown")).accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isNotFound())
        .andExpect(jsonPath("$.message").value("Unknown product id: unknown"));

    mockMvc
        .perform(withSession(post("/addproduct/99")).accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isNotFound())
        .andExpect(jsonPath("$.message").value("Unknown product id: 99"));
  }

  @Test
  @DisplayName("Different session ids keep independent carts")
  void cartsAreIsolatedPerSession() throws Exception {
    mockMvc.perform(withSession(post("/addproduct/1"))).andExpect(status().isOk());

    mockMvc
        .perform(
            withSession(get("/getcart"), OTHER_SESSION_ID, OTHER_USERNAME)
                .accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.lineItems", org.hamcrest.Matchers.hasSize(0)))
        .andExpect(jsonPath("$.total").value(0));

    mockMvc
        .perform(withSession(get("/getcart")).accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.lineItems", org.hamcrest.Matchers.hasSize(1)));
  }

  @Test
  @DisplayName("Missing X-Session-Username returns 400")
  void missingUsername_returns400() throws Exception {
    mockMvc
        .perform(get("/getcart").header("X-Session-Id", "only-id"))
        .andExpect(status().isBadRequest());
  }
}
