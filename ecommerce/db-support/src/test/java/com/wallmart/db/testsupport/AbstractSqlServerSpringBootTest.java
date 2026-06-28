package com.wallmart.db.testsupport;

import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.MSSQLServerContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

/**
 * Shared Testcontainers SQL Server for service integration tests. Subclasses should also declare
 * {@code @SpringBootTest} and {@code @AutoConfigureMockMvc} as needed.
 */
@Testcontainers(disabledWithoutDocker = true)
public abstract class AbstractSqlServerSpringBootTest {

  private static final DockerImageName IMAGE =
      DockerImageName.parse("mcr.microsoft.com/mssql/server:2022-latest");

  @Container
  @SuppressWarnings("resource")
  static final MSSQLServerContainer<?> SQL_SERVER =
      new MSSQLServerContainer<>(IMAGE).acceptLicense();

  @DynamicPropertySource
  static void sqlServerProperties(DynamicPropertyRegistry registry) {
    SqlServerTestSupport.registerProperties(registry, SQL_SERVER);
  }
}
