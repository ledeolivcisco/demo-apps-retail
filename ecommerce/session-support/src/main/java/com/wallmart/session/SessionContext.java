package com.wallmart.session;

public final class SessionContext {

  private static final ThreadLocal<SessionInfo> CURRENT = new ThreadLocal<>();

  private SessionContext() {}

  public static void set(SessionInfo info) {
    CURRENT.set(info);
  }

  public static SessionInfo get() {
    return CURRENT.get();
  }

  public static SessionInfo require() {
    SessionInfo info = CURRENT.get();
    if (info == null) {
      throw new IllegalStateException("No session in context");
    }
    return info;
  }

  public static void clear() {
    CURRENT.remove();
  }
}
