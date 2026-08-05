package com.wallmart.appliance.graphql;

import com.wallmart.db.testsupport.AbstractSqlServerSpringBootTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.graphql.tester.AutoConfigureHttpGraphQlTester;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.graphql.test.tester.HttpGraphQlTester;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.annotation.DirtiesContext.ClassMode;

@SpringBootTest
@AutoConfigureHttpGraphQlTester
@DirtiesContext(classMode = ClassMode.AFTER_EACH_TEST_METHOD)
class ApplianceGraphQlControllerApiTest extends AbstractSqlServerSpringBootTest {

  @Autowired private HttpGraphQlTester graphQlTester;

  @Test
  @DisplayName("Query appliances returns seeded catalog with stock")
  void appliances_returnsAll() {
    graphQlTester
        .document(
            """
            {
              appliances {
                applianceId
                applianceType
                stock
              }
            }
            """)
        .execute()
        .path("appliances")
        .entityList(Object.class)
        .hasSize(9)
        .path("appliances[0].applianceId")
        .entity(String.class)
        .isEqualTo("A1")
        .path("appliances[0].stock")
        .entity(Integer.class)
        .isEqualTo(50);
  }

  @Test
  @DisplayName("Query appliances filters by type")
  void appliances_filtersByType() {
    graphQlTester
        .document(
            """
            {
              appliances(type: FRIDGE) {
                applianceId
                applianceType
              }
            }
            """)
        .execute()
        .path("appliances")
        .entityList(Object.class)
        .hasSize(3)
        .path("appliances[0].applianceType")
        .entity(String.class)
        .isEqualTo("FRIDGE");
  }

  @Test
  @DisplayName("Query appliances filters by search text")
  void appliances_filtersBySearch() {
    graphQlTester
        .document(
            """
            {
              appliances(search: "French Door") {
                applianceId
                applianceDescription
              }
            }
            """)
        .execute()
        .path("appliances")
        .entityList(Object.class)
        .hasSize(1)
        .path("appliances[0].applianceId")
        .entity(String.class)
        .isEqualTo("A1");
  }

  @Test
  @DisplayName("Mutation deductApplianceStock reduces stock")
  void deductApplianceStock_reducesStock() {
    graphQlTester
        .document(
            """
            mutation {
              deductApplianceStock(applianceId: "A1", quantity: 5) {
                applianceId
                stock
              }
            }
            """)
        .execute()
        .path("deductApplianceStock.applianceId")
        .entity(String.class)
        .isEqualTo("A1")
        .path("deductApplianceStock.stock")
        .entity(Integer.class)
        .isEqualTo(45);
  }

  @Test
  @DisplayName("Mutation deductApplianceStock returns error when stock insufficient")
  void deductApplianceStock_insufficientStock_returnsError() {
    graphQlTester
        .document(
            """
            mutation {
              deductApplianceStock(applianceId: "A2", quantity: 1000) {
                applianceId
                stock
              }
            }
            """)
        .execute()
        .errors()
        .expect(error -> error.getMessage().contains("Insufficient stock"))
        .verify();
  }

  @Test
  @DisplayName("Mutation restoreApplianceStock adds stock back")
  void restoreApplianceStock_increasesStock() {
    graphQlTester
        .document(
            """
            mutation {
              deductApplianceStock(applianceId: "A3", quantity: 10) {
                stock
              }
            }
            """)
        .execute()
        .path("deductApplianceStock.stock")
        .entity(Integer.class)
        .isEqualTo(90);

    graphQlTester
        .document(
            """
            mutation {
              restoreApplianceStock(applianceId: "A3", quantity: 10) {
                applianceId
                stock
              }
            }
            """)
        .execute()
        .path("restoreApplianceStock.stock")
        .entity(Integer.class)
        .isEqualTo(100);
  }
}
