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
      USING (SELECT ? AS session_id, ? AS item_type, ? AS item_id, ? AS quantity, ? AS unit_price) AS source
      ON target.session_id = source.session_id
        AND target.item_type = source.item_type
        AND target.item_id = source.item_id
      WHEN MATCHED THEN UPDATE SET quantity = target.quantity + source.quantity
      WHEN NOT MATCHED THEN INSERT (session_id, item_type, item_id, quantity, unit_price)
        VALUES (source.session_id, source.item_type, source.item_id, source.quantity, source.unit_price);
      """;

  private static final String SELECT_CART =
      """
      SELECT c.item_type, c.item_id, c.quantity,
             COALESCE(p.product_description, a.appliance_description) AS description,
             COALESCE(c.unit_price, p.product_price, a.appliance_price) AS price,
             COALESCE(p.product_picture, a.appliance_picture) AS picture
      FROM cart_line c
      LEFT JOIN products p ON c.item_type = 'PRODUCT' AND p.product_id = c.item_id
      LEFT JOIN appliances a ON c.item_type = 'APPLIANCE' AND a.appliance_id = c.item_id
      WHERE c.session_id = ?
      ORDER BY c.item_type, c.item_id
      """;

  private final JdbcTemplate jdbc;

  public JdbcCartRepository(JdbcTemplate jdbc) {
    this.jdbc = jdbc;
  }

  public void addItem(String sessionId, String itemType, String itemId) {
    addItem(sessionId, itemType, itemId, null);
  }

  public void addItem(String sessionId, String itemType, String itemId, BigDecimal unitPrice) {
    jdbc.update(MERGE_LINE, sessionId, itemType, itemId, 1, unitPrice);
  }

  public CartResponse getCart(String sessionId) {
    List<CartLineItem> items =
        jdbc.query(
            SELECT_CART,
            (rs, rowNum) ->
                new CartLineItem(
                    rs.getString("item_type"),
                    rs.getString("item_id"),
                    rs.getString("description"),
                    rs.getBigDecimal("price"),
                    rs.getString("picture"),
                    rs.getInt("quantity")),
            sessionId);

    BigDecimal total = BigDecimal.ZERO;
    for (CartLineItem item : items) {
      total = total.add(item.price().multiply(BigDecimal.valueOf(item.quantity())));
    }
    total = total.setScale(MONEY_SCALE, RoundingMode.HALF_UP);
    return new CartResponse(items, total);
  }

  public void clearCart(String sessionId) {
    jdbc.update("DELETE FROM cart_line WHERE session_id = ?", sessionId);
  }
}
