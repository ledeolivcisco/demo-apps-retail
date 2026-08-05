package com.wallmart.appliance.graphql;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import com.wallmart.appliance.pricing.AppliancePricingApi;
import com.wallmart.db.testsupport.AbstractSqlServerSpringBootTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.graphql.tester.AutoConfigureHttpGraphQlTester;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.graphql.test.tester.HttpGraphQlTester;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.annotation.DirtiesContext.ClassMode;

@SpringBootTest
@AutoConfigureHttpGraphQlTester
@DirtiesContext(classMode = ClassMode.AFTER_EACH_TEST_METHOD)
class ApplianceGraphQlControllerPricingDisabledTest extends AbstractSqlServerSpringBootTest {

  @Autowired private HttpGraphQlTester graphQlTester;

  @MockBean private AppliancePricingApi appliancePricingApi;

  @Test
  @DisplayName("Query appliances skips lambda when GET_PRICE is disabled")
  void appliances_skipsLambdaWhenDisabled() {
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
        .contains(1299.99);

    verify(appliancePricingApi, never()).getPrice(anyString());
  }
}
