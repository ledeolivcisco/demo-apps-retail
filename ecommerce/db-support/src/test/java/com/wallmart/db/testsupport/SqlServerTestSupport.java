package com.wallmart.db.testsupport;

import org.springframework.test.context.DynamicPropertyRegistry;
import org.testcontainers.containers.MSSQLServerContainer;

/** Registers JDBC properties for a running Testcontainers SQL Server instance. */
public final class SqlServerTestSupport {

  private SqlServerTestSupport() {}

  public static void registerProperties(
      DynamicPropertyRegistry registry, MSSQLServerContainer<?> container) {
    registry.add("WALLMART_DB_HOST", container::getHost);
    registry.add("WALLMART_DB_PORT", () -> container.getMappedPort(1433).toString());
    registry.add("WALLMART_DB_NAME", () -> "wallmart");
    registry.add("WALLMART_DB_USER", container::getUsername);
    registry.add("WALLMART_DB_PASSWORD", container::getPassword);
    registry.add("WALLMART_DB_BOOTSTRAP", () -> "true");
  }
}
