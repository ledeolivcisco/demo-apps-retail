package com.wallmart.product.web;

import static com.wallmart.product.support.SessionTestSupport.withSession;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.wallmart.db.testsupport.AbstractSqlServerSpringBootTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
class ProductControllerApiTest extends AbstractSqlServerSpringBootTest {

  @Autowired private MockMvc mockMvc;

  @Test
  @DisplayName("GET /productsearch returns 200 and full catalog of 10 products")
  void productSearch_returnsFullInventory() throws Exception {
    mockMvc
        .perform(withSession(get("/productsearch")).accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$", hasSize(10)))
        .andExpect(jsonPath("$[0].productId").value("1"))
        .andExpect(jsonPath("$[0].productDescription").value("Whole Wheat Bread"))
        .andExpect(jsonPath("$[0].productPrice").value(3.49))
        .andExpect(jsonPath("$[0].productPicture").exists())
        .andExpect(jsonPath("$[0].stock").value(999))
        .andExpect(jsonPath("$[9].productId").value("10"))
        .andExpect(jsonPath("$[9].productDescription").value("Butter 1 lb"));
  }

  @Test
  @DisplayName("GET /productsearch without username returns 400")
  void productSearch_missingUsername_returns400() throws Exception {
    mockMvc
        .perform(get("/productsearch").header("X-Session-Id", "only-id"))
        .andExpect(status().isBadRequest());
  }
}
