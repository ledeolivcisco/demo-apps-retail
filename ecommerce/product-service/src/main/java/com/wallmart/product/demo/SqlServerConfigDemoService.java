package com.wallmart.product.demo;

import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

@Service
public class SqlServerConfigDemoService {

  private static final Logger log = LoggerFactory.getLogger(SqlServerConfigDemoService.class);

  /** {@code sp_configure} name; {@code sys.configurations.name} includes the {@code (s)} suffix. */
  private static final String CONFIG_NAME = "blocked process threshold";

  private static final String READ_THRESHOLD_SQL =
      """
      SELECT CAST(value_in_use AS INT)
      FROM sys.configurations
      WHERE name LIKE ?
      """;

  private final JdbcTemplate jdbc;

  public SqlServerConfigDemoService(JdbcTemplate jdbc) {
    this.jdbc = jdbc;
  }

  public int readBlockedProcessThreshold() {
    Integer value =
        jdbc.query(
                READ_THRESHOLD_SQL,
                (rs, rowNum) -> rs.getInt(1),
                CONFIG_NAME + "%")
            .stream()
            .findFirst()
            .orElse(0);
    return value;
  }

  public int setBlockedProcessThreshold(int seconds) {
    int previous = readBlockedProcessThreshold();
    applyThreshold(seconds);
    log.info("event=demo.db_config.changed config={} value={} previous={}", CONFIG_NAME, seconds, previous);
    return previous;
  }

  public int restoreBlockedProcessThreshold() {
    return setBlockedProcessThreshold(0);
  }

  private void applyThreshold(int seconds) {
    jdbc.execute(
        (Connection conn) -> {
          boolean originalAutoCommit = conn.getAutoCommit();
          try {
            conn.setAutoCommit(true);
            try (Statement stmt = conn.createStatement()) {
              executeSql(stmt, "EXEC sp_configure 'show advanced options', 1");
              executeSql(stmt, "RECONFIGURE");
              executeSql(stmt, "EXEC sp_configure '" + CONFIG_NAME + "', " + seconds);
              executeSql(stmt, "RECONFIGURE");
            }
          } catch (SQLException e) {
            throw new IllegalStateException("Failed to configure blocked process threshold", e);
          } finally {
            conn.setAutoCommit(originalAutoCommit);
          }
          return null;
        });
  }

  private static void executeSql(Statement stmt, String sql) throws SQLException {
    if (stmt.execute(sql)) {
      do {
        try (ResultSet rs = stmt.getResultSet()) {
          while (rs != null && rs.next()) {
            // drain rows from sp_configure result sets
          }
        }
      } while (stmt.getMoreResults());
    }
  }
}
