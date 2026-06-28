package com.wallmart.cart.catalog;

import com.wallmart.cart.model.Product;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Component
public class JdbcProductLookup {

  private static final String SELECT_BY_ID =
      """
      SELECT product_id, product_description, product_price, product_picture
      FROM products
      WHERE product_id = ?
      """;

  private final JdbcTemplate jdbc;

  public JdbcProductLookup(JdbcTemplate jdbc) {
    this.jdbc = jdbc;
  }

  public Optional<Product> findById(String productId) {
    return jdbc.query(
            SELECT_BY_ID,
            (rs, rowNum) ->
                new Product(
                    rs.getString("product_id"),
                    rs.getString("product_description"),
                    rs.getBigDecimal("product_price"),
                    rs.getString("product_picture")),
            productId)
        .stream()
        .findFirst();
  }
}
