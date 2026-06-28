package com.wallmart.cart.repository;

import com.wallmart.cart.model.CartLineItem;
import com.wallmart.cart.model.CartResponse;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcCartRepository {

  private static final int MONEY_SCALE = 2;

  private static final String MERGE_LINE =
      """
      MERGE cart_line AS target
      USING (SELECT ? AS session_id, ? AS product_id, ? AS quantity) AS source
      ON target.session_id = source.session_id AND target.product_id = source.product_id
      WHEN MATCHED THEN UPDATE SET quantity = target.quantity + source.quantity
      WHEN NOT MATCHED THEN INSERT (session_id, product_id, quantity)
        VALUES (source.session_id, source.product_id, source.quantity);
      """;

  private static final String SELECT_CART =
      """
      SELECT c.product_id, p.product_description, p.product_price, p.product_picture, c.quantity
      FROM cart_line c
      JOIN products p ON p.product_id = c.product_id
      WHERE c.session_id = ?
      ORDER BY c.product_id
      """;

  private final JdbcTemplate jdbc;

  public JdbcCartRepository(JdbcTemplate jdbc) {
    this.jdbc = jdbc;
  }

  public void addProduct(String sessionId, String productId) {
    jdbc.update(MERGE_LINE, sessionId, productId, 1);
  }

  public CartResponse getCart(String sessionId) {
    List<CartLineItem> items =
        jdbc.query(
            SELECT_CART,
            (rs, rowNum) ->
                new CartLineItem(
                    rs.getString("product_id"),
                    rs.getString("product_description"),
                    rs.getBigDecimal("product_price"),
                    rs.getString("product_picture"),
                    rs.getInt("quantity")),
            sessionId);

    BigDecimal total = BigDecimal.ZERO;
    for (CartLineItem item : items) {
      total =
          total.add(
              item.productPrice().multiply(BigDecimal.valueOf(item.quantity())));
    }
    total = total.setScale(MONEY_SCALE, RoundingMode.HALF_UP);
    return new CartResponse(items, total);
  }

  public void clearCart(String sessionId) {
    jdbc.update("DELETE FROM cart_line WHERE session_id = ?", sessionId);
  }
}
