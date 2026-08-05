package com.wallmart.appliance.graphql;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.wallmart.appliance.pricing.AppliancePricingApi;
import com.wallmart.appliance.pricing.AppliancePricingException;
import com.wallmart.db.testsupport.AbstractSqlServerSpringBootTest;
import java.math.BigDecimal;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.graphql.tester.AutoConfigureHttpGraphQlTester;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.graphql.test.tester.HttpGraphQlTester;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.annotation.DirtiesContext.ClassMode;
import org.springframework.test.context.TestPropertySource;

@SpringBootTest
@AutoConfigureHttpGraphQlTester
@DirtiesContext(classMode = ClassMode.AFTER_EACH_TEST_METHOD)
@TestPropertySource(properties = "wallmart.get-price=true")
class ApplianceGraphQlControllerPricingTest extends AbstractSqlServerSpringBootTest {

  @Autowired private HttpGraphQlTester graphQlTester;

  @MockBean private AppliancePricingApi appliancePricingApi;

  @Test
  @DisplayName("Query appliances uses lambda price when GET_PRICE is enabled")
  void appliances_usesLambdaPrice() {
    when(appliancePricingApi.getPrice(anyString())).thenReturn(new BigDecimal("1234.00"));

    graphQlTester
        .document(
            """
            {
              appliances {
                applianceId
                appliancePrice
              }
            }
            """)
        .execute()
        .path("appliances[?(@.applianceId == 'A1')].appliancePrice")
        .entityList(Double.class)
        .contains(1234.0);

    verify(appliancePricingApi).getPrice("A1");
  }

  @Test
  @DisplayName("Query appliance uses lambda price for a single item")
  void appliance_usesLambdaPrice() {
    when(appliancePricingApi.getPrice("A1")).thenReturn(new BigDecimal("4321.00"));

    graphQlTester
        .document(
            """
            {
              appliance(applianceId: "A1") {
                applianceId
                appliancePrice
              }
            }
            """)
        .execute()
        .path("appliance.appliancePrice")
        .entity(Double.class)
        .isEqualTo(4321.0);

    verify(appliancePricingApi).getPrice("A1");
  }

  @Test
  @DisplayName("Query appliances returns GraphQL error when pricing fails")
  void appliances_pricingFailure_returnsError() {
    when(appliancePricingApi.getPrice(anyString()))
        .thenThrow(new AppliancePricingException(502, "Pricing service unavailable"));

    graphQlTester
        .document(
            """
            {
              appliances {
                applianceId
                appliancePrice
              }
            }
            """)
        .execute()
        .errors()
        .expect(error -> error.getMessage().contains("Pricing service unavailable"))
        .verify();
  }
}
