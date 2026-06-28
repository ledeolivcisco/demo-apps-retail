package com.wallmart.session;

import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.core.Ordered;

@AutoConfiguration
@ComponentScan(basePackageClasses = SessionRegistry.class)
public class SessionAutoConfiguration {

  @Bean
  FilterRegistrationBean<SessionServletFilter> sessionServletFilter() {
    FilterRegistrationBean<SessionServletFilter> registration = new FilterRegistrationBean<>();
    registration.setFilter(new SessionServletFilter());
    registration.setOrder(Ordered.HIGHEST_PRECEDENCE);
    registration.addUrlPatterns("/*");
    return registration;
  }
}
