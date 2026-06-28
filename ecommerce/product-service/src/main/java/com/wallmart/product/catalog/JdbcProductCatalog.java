package com.wallmart.product.catalog;

import com.wallmart.product.inventory.InsufficientStockException;
import com.wallmart.product.inventory.InventoryLine;
import com.wallmart.product.model.Product;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
public class JdbcProductCatalog {

  private static final Logger log = LoggerFactory.getLogger(JdbcProductCatalog.class);

  private static final String SELECT_ALL =
      """
      SELECT p.product_id, p.product_description, p.product_price, p.product_picture, i.stock
      FROM products p
      JOIN inventory i ON i.product_id = p.product_id
      ORDER BY p.product_id
      """;

  private final JdbcTemplate jdbc;

  public JdbcProductCatalog(JdbcTemplate jdbc) {
    this.jdbc = jdbc;
  }

  public List<Product> allProducts() {
    return jdbc.query(
        SELECT_ALL,
        (rs, rowNum) ->
            new Product(
                rs.getString("product_id"),
                rs.getString("product_description"),
                rs.getBigDecimal("product_price"),
                rs.getString("product_picture"),
                rs.getInt("stock")));
  }

  @Transactional
  public void applyDeduction(List<InventoryLine> lines) {
    for (InventoryLine line : lines) {
      if (line.quantity() <= 0) {
        throw new IllegalArgumentException(
            "Quantity must be positive for product " + line.productId());
      }
      Integer exists =
          jdbc.queryForObject(
              "SELECT COUNT(*) FROM products WHERE product_id = ?",
              Integer.class,
              line.productId());
      if (exists == null || exists == 0) {
        throw new IllegalArgumentException("Unknown product id: " + line.productId());
      }
    }
    for (InventoryLine line : lines) {
      int updated =
          jdbc.update(
              "UPDATE inventory SET stock = stock - ? WHERE product_id = ? AND stock >= ?",
              line.quantity(),
              line.productId(),
              line.quantity());
      if (updated == 0) {
        Integer current =
            jdbc.queryForObject(
                "SELECT stock FROM inventory WHERE product_id = ?",
                Integer.class,
                line.productId());
        int have = current != null ? current : 0;
        log.warn(
            "event=inventory.deduct.conflict productId={} have={} need={}",
            line.productId(),
            have,
            line.quantity());
        throw new InsufficientStockException(
            "Insufficient stock for product "
                + line.productId()
                + " (have "
                + have
                + ", need "
                + line.quantity()
                + ")");
      }
    }
    log.info("event=inventory.deducted lineCount={}", lines.size());
  }

  @Transactional
  public void applyRestore(List<InventoryLine> lines) {
    for (InventoryLine line : lines) {
      if (line.quantity() <= 0) {
        continue;
      }
      jdbc.update(
          "UPDATE inventory SET stock = stock + ? WHERE product_id = ?",
          line.quantity(),
          line.productId());
    }
    if (lines != null && !lines.isEmpty()) {
      log.info("event=inventory.restored lineCount={}", lines.size());
    }
  }
}
