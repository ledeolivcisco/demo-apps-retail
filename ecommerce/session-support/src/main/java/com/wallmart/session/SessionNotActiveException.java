package com.wallmart.session;

public class SessionNotActiveException extends RuntimeException {

  public SessionNotActiveException(String message) {
    super(message);
  }
}
