package com.wallmart.appliance.graphql;

import com.wallmart.appliance.catalog.JdbcApplianceCatalog;
import com.wallmart.appliance.model.Appliance;
import com.wallmart.appliance.model.ApplianceType;
import com.wallmart.appliance.pricing.AppliancePricingApi;
import java.math.BigDecimal;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.graphql.data.method.annotation.Argument;
import org.springframework.graphql.data.method.annotation.MutationMapping;
import org.springframework.graphql.data.method.annotation.QueryMapping;
import org.springframework.stereotype.Controller;

@Controller
public class ApplianceGraphQlController {

  private static final Logger log = LoggerFactory.getLogger(ApplianceGraphQlController.class);

  private final JdbcApplianceCatalog catalog;
  private final AppliancePricingApi appliancePricingApi;
  private final boolean getPrice;

  public ApplianceGraphQlController(
      JdbcApplianceCatalog catalog,
      AppliancePricingApi appliancePricingApi,
      @Value("${wallmart.get-price:false}") boolean getPrice) {
    this.catalog = catalog;
    this.appliancePricingApi = appliancePricingApi;
    this.getPrice = getPrice;
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
    return results.stream().map(this::withDynamicPrice).toList();
  }

  @QueryMapping
  public Appliance appliance(@Argument String applianceId) {
    Appliance result = catalog.findById(applianceId).orElse(null);
    return result == null ? null : withDynamicPrice(result);
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

  private Appliance withDynamicPrice(Appliance appliance) {
    if (!getPrice) {
      return appliance;
    }
    BigDecimal price = appliancePricingApi.getPrice(appliance.applianceId());
    return new Appliance(
        appliance.applianceId(),
        appliance.applianceType(),
        appliance.applianceDescription(),
        price,
        appliance.appliancePicture(),
        appliance.stock());
  }
}
