package com.wallmart.appliance.graphql;

import com.wallmart.appliance.catalog.JdbcApplianceCatalog;
import com.wallmart.appliance.inventory.InsufficientApplianceStockException;
import com.wallmart.appliance.model.Appliance;
import com.wallmart.appliance.model.ApplianceType;
import graphql.GraphQLError;
import graphql.GraphqlErrorBuilder;
import graphql.schema.DataFetchingEnvironment;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.graphql.data.method.annotation.Argument;
import org.springframework.graphql.data.method.annotation.GraphQlExceptionHandler;
import org.springframework.graphql.data.method.annotation.MutationMapping;
import org.springframework.graphql.data.method.annotation.QueryMapping;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.ControllerAdvice;

@Controller
public class ApplianceGraphQlController {

  private static final Logger log = LoggerFactory.getLogger(ApplianceGraphQlController.class);

  private final JdbcApplianceCatalog catalog;

  public ApplianceGraphQlController(JdbcApplianceCatalog catalog) {
    this.catalog = catalog;
  }

  @QueryMapping
  public List<Appliance> appliances(
      @Argument ApplianceType type, @Argument String search) {
    List<Appliance> results = catalog.search(type, search);
    log.info(
        "event=appliance.catalog.searched type={} search={} resultCount={}",
        type,
        search,
        results.size());
    return results;
  }

  @QueryMapping
  public Appliance appliance(@Argument String applianceId) {
    return catalog.findById(applianceId).orElse(null);
  }

  @MutationMapping
  public Appliance deductApplianceStock(
      @Argument String applianceId, @Argument int quantity) {
    return catalog.deductStock(applianceId, quantity);
  }

  @MutationMapping
  public Appliance restoreApplianceStock(
      @Argument String applianceId, @Argument int quantity) {
    return catalog.restoreStock(applianceId, quantity);
  }
}
