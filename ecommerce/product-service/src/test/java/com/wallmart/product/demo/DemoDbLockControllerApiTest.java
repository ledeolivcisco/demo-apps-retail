package com.wallmart.product.demo;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.wallmart.db.testsupport.AbstractSqlServerSpringBootTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.annotation.DirtiesContext.ClassMode;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@DirtiesContext(classMode = ClassMode.AFTER_EACH_TEST_METHOD)
class DemoDbLockControllerApiTest extends AbstractSqlServerSpringBootTest {

  @Autowired private MockMvc mockMvc;

  @Test
  @DisplayName("POST /internal/demo/db-lock/inventory returns 404 when chaos disabled")
  void lockInventory_chaosDisabled_returns404() throws Exception {
    mockMvc
        .perform(post("/internal/demo/db-lock/inventory").param("seconds", "5"))
        .andExpect(status().isNotFound());
  }
}

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = "WALLMART_DEMO_CHAOS_ENABLED=true")
@DirtiesContext(classMode = ClassMode.AFTER_EACH_TEST_METHOD)
class DemoDbLockControllerEnabledApiTest extends AbstractSqlServerSpringBootTest {

  @Autowired private MockMvc mockMvc;

  @Test
  @DisplayName("POST /internal/demo/db-lock/inventory accepts valid request when chaos enabled")
  void lockInventory_chaosEnabled_returns202() throws Exception {
    mockMvc
        .perform(post("/internal/demo/db-lock/inventory").param("seconds", "5").param("mode", "row"))
        .andExpect(status().isAccepted())
        .andExpect(jsonPath("$.seconds").value(5))
        .andExpect(jsonPath("$.mode").value("row"));
  }

  @Test
  @DisplayName("POST /internal/demo/db-lock/inventory validates seconds")
  void lockInventory_invalidSeconds_returns400() throws Exception {
    mockMvc
        .perform(post("/internal/demo/db-lock/inventory").param("seconds", "2"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.message").exists());
  }
}
