package com.wallmart.db;

import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;
import javax.sql.DataSource;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.jdbc.DataSourceBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.core.env.Environment;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;

@AutoConfiguration(after = DataSourceAutoConfiguration.class)
@EnableConfigurationProperties(DbProperties.class)
public class DbAutoConfiguration {

  @Bean
  DbBootstrapState dbBootstrapState() {
    return new DbBootstrapState();
  }

  @Bean
  DatabaseBootstrap databaseBootstrap(
      DataSource dataSource,
      DbProperties dbProperties,
      DbBootstrapState bootstrapState,
      Environment environment) {
    return new DatabaseBootstrap(dataSource, dbProperties, bootstrapState, environment);
  }

  static final class DatabaseBootstrap {

    private final DataSource dataSource;
    private final DbProperties dbProperties;
    private final DbBootstrapState bootstrapState;
    private final Environment environment;

    DatabaseBootstrap(
        DataSource dataSource,
        DbProperties dbProperties,
        DbBootstrapState bootstrapState,
        Environment environment) {
      this.dataSource = dataSource;
      this.dbProperties = dbProperties;
      this.bootstrapState = bootstrapState;
      this.environment = environment;
    }

    @jakarta.annotation.PostConstruct
    void bootstrap() {
      if (dbProperties.bootstrap()) {
        ensureDatabaseExists();
        runScripts("classpath:db/schema.sql", "classpath:db/data.sql");
      }
      bootstrapState.markComplete();
    }

    private void ensureDatabaseExists() {
      String dbName = environment.getProperty("WALLMART_DB_NAME", "wallmart");
      String host = environment.getProperty("WALLMART_DB_HOST", "localhost");
      String port = environment.getProperty("WALLMART_DB_PORT", "1433");
      String user = environment.getProperty("WALLMART_DB_USER", "sa");
      String password = environment.getProperty("WALLMART_DB_PASSWORD", "YourStrong!Passw0rd");

      String masterUrl =
          "jdbc:sqlserver://"
              + host
              + ":"
              + port
              + ";databaseName=master;encrypt=false;trustServerCertificate=true";

      DataSource masterDs =
          DataSourceBuilder.create()
              .url(masterUrl)
              .username(user)
              .password(password)
              .driverClassName("com.microsoft.sqlserver.jdbc.SQLServerDriver")
              .build();

      String sql =
          "IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'"
              + dbName.replace("'", "''")
              + "') CREATE DATABASE ["
              + dbName.replace("]", "]]")
              + "]";

      try (Connection conn = masterDs.getConnection();
          Statement stmt = conn.createStatement()) {
        stmt.execute(sql);
      } catch (SQLException e) {
        throw new IllegalStateException("Failed to ensure database exists: " + dbName, e);
      }
    }

    private void runScripts(String... locations) {
      ResourceDatabasePopulator populator = new ResourceDatabasePopulator();
      for (String location : locations) {
        populator.addScript(new ClassPathResource(location.replace("classpath:", "")));
      }
      populator.setSeparator(";");
      populator.setContinueOnError(false);
      try {
        populator.execute(dataSource);
      } catch (Exception e) {
        throw new IllegalStateException("Database bootstrap scripts failed", e);
      }
    }
  }
}
