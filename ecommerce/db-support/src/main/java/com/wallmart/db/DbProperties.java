package com.wallmart.db;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "wallmart.db")
public record DbProperties(boolean bootstrap) {}
