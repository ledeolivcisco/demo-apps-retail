package com.wallmart.product.demo;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.concurrent.atomic.AtomicBoolean;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Service;

@Service
public class InventoryDemoLockService {

  private static final Logger log = LoggerFactory.getLogger(InventoryDemoLockService.class);

  private final Environment environment;
  private final AtomicBoolean lockActive = new AtomicBoolean(false);

  public InventoryDemoLockService(Environment environment) {
    this.environment = environment;
  }

  public boolean tryStartLock() {
    return lockActive.compareAndSet(false, true);
  }

  public void clearLockActive() {
    lockActive.set(false);
  }

  public boolean isLockActive() {
    return lockActive.get();
  }

  public void holdInventoryLock(int seconds, String mode) throws SQLException {
    String host = environment.getProperty("WALLMART_DB_HOST", "localhost");
    String port = environment.getProperty("WALLMART_DB_PORT", "1433");
    String dbName = environment.getProperty("WALLMART_DB_NAME", "wallmart");
    String user = environment.getProperty("WALLMART_DB_USER", "sa");
    String password = environment.getProperty("WALLMART_DB_PASSWORD", "YourStrong!Passw0rd");

    String url =
        "jdbc:sqlserver://"
            + host
            + ":"
            + port
            + ";databaseName="
            + dbName
            + ";encrypt=false;trustServerCertificate=true";

    log.info("event=demo.db_lock.started mode={} seconds={}", mode, seconds);

    try (Connection conn = DriverManager.getConnection(url, user, password)) {
      conn.setAutoCommit(false);
      try (Statement stmt = conn.createStatement()) {
        if ("row".equals(mode)) {
          stmt.execute(
              "SELECT stock FROM inventory WITH (UPDLOCK, HOLDLOCK) WHERE product_id = '1'");
        } else {
          stmt.execute("UPDATE inventory WITH (TABLOCKX) SET stock = stock");
        }
        Thread.sleep(seconds * 1000L);
      } catch (InterruptedException e) {
        Thread.currentThread().interrupt();
        log.warn("event=demo.db_lock.interrupted mode={} seconds={}", mode, seconds);
      } finally {
        conn.rollback();
      }
    }

    log.info("event=demo.db_lock.released mode={} seconds={}", mode, seconds);
  }
}
