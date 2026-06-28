package com.wallmart.session;

public record SessionRecord(String sessionId, String username, SessionState state) {}
