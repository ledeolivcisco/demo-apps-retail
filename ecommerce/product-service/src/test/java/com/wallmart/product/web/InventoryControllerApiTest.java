package com.wallmart.product.web;

import static com.wallmart.product.support.SessionTestSupport.withSession;
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
class InventoryControllerApiTest extends AbstractSqlServerSpringBootTest {

  @Autowired private MockMvc mockMvc;

  @Test
  @DisplayName("POST /internal/inventory/deduct reduces stock visible on GET /productsearch")
  void deduct_then_search_shows_lowerStock() throws Exception {
    mockMvc
        .perform(
            withSession(post("/internal/inventory/deduct"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("[{\"productId\":\"1\",\"quantity\":5}]"))
        .andExpect(status().isNoContent());

    mockMvc
        .perform(withSession(get("/productsearch")).accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$[0].productId").value("1"))
        .andExpect(jsonPath("$[0].stock").value(994));
  }

  @Test
  @DisplayName("POST /internal/inventory/deduct returns 409 when stock insufficient")
  void deduct_insufficientStock_returns409() throws Exception {
    mockMvc
        .perform(
            withSession(post("/internal/inventory/deduct"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("[{\"productId\":\"2\",\"quantity\":1000}]"))
        .andExpect(status().isConflict())
        .andExpect(jsonPath("$.message").exists());
  }

  @Test
  @DisplayName("POST /internal/inventory/restore adds stock back")
  void restore_increasesStock() throws Exception {
    mockMvc
        .perform(
            withSession(post("/internal/inventory/deduct"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("[{\"productId\":\"3\",\"quantity\":10}]"))
        .andExpect(status().isNoContent());

    mockMvc
        .perform(
            withSession(post("/internal/inventory/restore"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("[{\"productId\":\"3\",\"quantity\":10}]"))
        .andExpect(status().isNoContent());

    mockMvc
        .perform(withSession(get("/productsearch")).accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$[2].productId").value("3"))
        .andExpect(jsonPath("$[2].stock").value(999));
  }
}
