package com.wallmart.payment.repository;

import java.math.BigDecimal;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class PaymentTransactionRepository {

  private static final String INSERT =
      """
      INSERT INTO payment_transaction (session_id, username, amount, status, message)
      VALUES (?, ?, ?, ?, ?)
      """;

  private final JdbcTemplate jdbc;

  public PaymentTransactionRepository(JdbcTemplate jdbc) {
    this.jdbc = jdbc;
  }

  public void save(
      String sessionId, String username, BigDecimal amount, String status, String message) {
    jdbc.update(INSERT, sessionId, username, amount, status, message);
  }
}
