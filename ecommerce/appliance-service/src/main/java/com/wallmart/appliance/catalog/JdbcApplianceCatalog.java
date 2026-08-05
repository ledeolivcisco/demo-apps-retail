package com.wallmart.appliance.catalog;

import com.wallmart.appliance.inventory.InsufficientApplianceStockException;
import com.wallmart.appliance.model.Appliance;
import com.wallmart.appliance.model.ApplianceType;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
public class JdbcApplianceCatalog {

  private static final Logger log = LoggerFactory.getLogger(JdbcApplianceCatalog.class);

  private static final String SELECT_BASE =
      """
      SELECT a.appliance_id, a.appliance_type, a.appliance_description,
             a.appliance_price, a.appliance_picture, i.stock
      FROM appliances a
      JOIN appliance_inventory i ON i.appliance_id = a.appliance_id
      """;

  private final JdbcTemplate jdbc;

  public JdbcApplianceCatalog(JdbcTemplate jdbc) {
    this.jdbc = jdbc;
  }

  public List<Appliance> search(ApplianceType type, String search) {
    StringBuilder sql = new StringBuilder(SELECT_BASE).append(" WHERE 1=1");
    List<Object> params = new ArrayList<>();
    if (type != null) {
      sql.append(" AND a.appliance_type = ?");
      params.add(type.name());
    }
    if (search != null && !search.isBlank()) {
      sql.append(" AND a.appliance_description LIKE ?");
      params.add("%" + search.trim() + "%");
    }
    sql.append(" ORDER BY a.appliance_id");
    return jdbc.query(sql.toString(), params.toArray(), this::mapRow);
  }

  public Optional<Appliance> findById(String applianceId) {
    List<Appliance> rows =
        jdbc.query(
            SELECT_BASE + " WHERE a.appliance_id = ?",
            this::mapRow,
            applianceId);
    return rows.isEmpty() ? Optional.empty() : Optional.of(rows.getFirst());
  }

  @Transactional
  public Appliance deductStock(String applianceId, int quantity) {
    validateQuantity(applianceId, quantity);
    ensureApplianceExists(applianceId);

    int updated =
        jdbc.update(
            "UPDATE appliance_inventory SET stock = stock - ? WHERE appliance_id = ? AND stock >= ?",
            quantity,
            applianceId,
            quantity);
    if (updated == 0) {
      Integer current =
          jdbc.queryForObject(
              "SELECT stock FROM appliance_inventory WHERE appliance_id = ?",
              Integer.class,
              applianceId);
      int have = current != null ? current : 0;
      log.warn(
          "event=appliance.inventory.deduct.conflict applianceId={} have={} need={}",
          applianceId,
          have,
          quantity);
      throw new InsufficientApplianceStockException(
          "Insufficient stock for appliance "
              + applianceId
              + " (have "
              + have
              + ", need "
              + quantity
              + ")");
    }

    log.info("event=appliance.inventory.deducted applianceId={} quantity={}", applianceId, quantity);
    return findById(applianceId).orElseThrow();
  }

  @Transactional
  public Appliance restoreStock(String applianceId, int quantity) {
    validateQuantity(applianceId, quantity);
    ensureApplianceExists(applianceId);

    jdbc.update(
        "UPDATE appliance_inventory SET stock = stock + ? WHERE appliance_id = ?",
        quantity,
        applianceId);

    log.info("event=appliance.inventory.restored applianceId={} quantity={}", applianceId, quantity);
    return findById(applianceId).orElseThrow();
  }

  private void ensureApplianceExists(String applianceId) {
    Integer exists =
        jdbc.queryForObject(
            "SELECT COUNT(*) FROM appliances WHERE appliance_id = ?",
            Integer.class,
            applianceId);
    if (exists == null || exists == 0) {
      throw new IllegalArgumentException("Unknown appliance id: " + applianceId);
    }
  }

  private static void validateQuantity(String applianceId, int quantity) {
    if (quantity <= 0) {
      throw new IllegalArgumentException(
          "Quantity must be positive for appliance " + applianceId);
    }
  }

  private Appliance mapRow(java.sql.ResultSet rs, int rowNum) throws java.sql.SQLException {
    return new Appliance(
        rs.getString("appliance_id"),
        ApplianceType.valueOf(rs.getString("appliance_type")),
        rs.getString("appliance_description"),
        rs.getBigDecimal("appliance_price"),
        rs.getString("appliance_picture"),
        rs.getInt("stock"));
  }
}
