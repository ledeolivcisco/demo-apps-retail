package com.wallmart.db;

import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.context.annotation.Bean;

@AutoConfiguration(after = DbAutoConfiguration.class)
@ConditionalOnClass(name = "org.springframework.boot.actuate.health.HealthIndicator")
public class DbActuatorAutoConfiguration {

  @Bean
  DbBootstrapHealthIndicator dbBootstrapHealthIndicator(DbBootstrapState bootstrapState) {
    return new DbBootstrapHealthIndicator(bootstrapState);
  }
}
