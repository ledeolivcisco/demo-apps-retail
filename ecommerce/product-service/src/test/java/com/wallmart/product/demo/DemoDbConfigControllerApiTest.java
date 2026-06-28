package com.wallmart.product.demo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.wallmart.db.testsupport.AbstractSqlServerSpringBootTest;
import org.junit.jupiter.api.AfterEach;
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
class DemoDbConfigControllerApiTest extends AbstractSqlServerSpringBootTest {

  @Autowired private MockMvc mockMvc;

  @Test
  @DisplayName("POST /internal/demo/db-config/blocked-process-threshold returns 404 when chaos disabled")
  void setThreshold_chaosDisabled_returns404() throws Exception {
    mockMvc
        .perform(post("/internal/demo/db-config/blocked-process-threshold").param("seconds", "10"))
        .andExpect(status().isNotFound());
  }

  @Test
  @DisplayName("POST restore returns 404 when chaos disabled")
  void restore_chaosDisabled_returns404() throws Exception {
    mockMvc
        .perform(post("/internal/demo/db-config/blocked-process-threshold/restore"))
        .andExpect(status().isNotFound());
  }
}

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = "WALLMART_DEMO_CHAOS_ENABLED=true")
@DirtiesContext(classMode = ClassMode.AFTER_EACH_TEST_METHOD)
class DemoDbConfigControllerEnabledApiTest extends AbstractSqlServerSpringBootTest {

  @Autowired private MockMvc mockMvc;

  @Autowired private SqlServerConfigDemoService configService;

  @AfterEach
  void restoreThreshold() {
    configService.restoreBlockedProcessThreshold();
  }

  @Test
  @DisplayName("POST /internal/demo/db-config/blocked-process-threshold sets value when chaos enabled")
  void setThreshold_chaosEnabled_returns200() throws Exception {
    mockMvc
        .perform(post("/internal/demo/db-config/blocked-process-threshold").param("seconds", "10"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.seconds").value(10))
        .andExpect(jsonPath("$.previous").exists());

    assertEquals(10, configService.readBlockedProcessThreshold());
  }

  @Test
  @DisplayName("POST /internal/demo/db-config/blocked-process-threshold validates seconds")
  void setThreshold_invalidSeconds_returns400() throws Exception {
    mockMvc
        .perform(post("/internal/demo/db-config/blocked-process-threshold").param("seconds", "2"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.message").exists());
  }

  @Test
  @DisplayName("POST restore disables blocked process threshold")
  void restore_chaosEnabled_returns200() throws Exception {
    configService.setBlockedProcessThreshold(15);

    mockMvc
        .perform(post("/internal/demo/db-config/blocked-process-threshold/restore"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.seconds").value(0))
        .andExpect(jsonPath("$.previous").value(15));

    assertEquals(0, configService.readBlockedProcessThreshold());
  }
}
