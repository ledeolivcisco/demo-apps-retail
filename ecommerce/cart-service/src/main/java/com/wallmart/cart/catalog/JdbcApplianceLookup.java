package com.wallmart.cart.catalog;

import com.wallmart.cart.model.Appliance;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Component
public class JdbcApplianceLookup {

  private static final String SELECT_BY_ID =
      """
      SELECT appliance_id, appliance_description, appliance_price, appliance_picture
      FROM appliances
      WHERE appliance_id = ?
      """;

  private final JdbcTemplate jdbc;

  public JdbcApplianceLookup(JdbcTemplate jdbc) {
    this.jdbc = jdbc;
  }

  public Optional<Appliance> findById(String applianceId) {
    return jdbc.query(
            SELECT_BY_ID,
            (rs, rowNum) ->
                new Appliance(
                    rs.getString("appliance_id"),
                    rs.getString("appliance_description"),
                    rs.getBigDecimal("appliance_price"),
                    rs.getString("appliance_picture")),
            applianceId)
        .stream()
        .findFirst();
  }
}
