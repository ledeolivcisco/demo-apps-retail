package com.wallmart.session;

public record SessionInfo(String sessionId, String username) {

  public SessionInfo {
    if (sessionId == null || sessionId.isBlank()) {
      throw new IllegalArgumentException("sessionId is required");
    }
    if (username == null || username.isBlank()) {
      throw new IllegalArgumentException("username is required");
    }
  }
}
