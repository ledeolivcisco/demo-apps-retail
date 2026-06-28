package com.wallmart.db;

import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;

public class DbBootstrapHealthIndicator implements HealthIndicator {

  private final DbBootstrapState bootstrapState;

  public DbBootstrapHealthIndicator(DbBootstrapState bootstrapState) {
    this.bootstrapState = bootstrapState;
  }

  @Override
  public Health health() {
    if (bootstrapState.isComplete()) {
      return Health.up().withDetail("bootstrap", "complete").build();
    }
    return Health.down().withDetail("bootstrap", "pending").build();
  }
}
