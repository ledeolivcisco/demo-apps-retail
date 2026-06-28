package com.wallmart.db;

import java.util.concurrent.atomic.AtomicBoolean;

public class DbBootstrapState {

  private final AtomicBoolean complete = new AtomicBoolean(false);

  public void markComplete() {
    complete.set(true);
  }

  public boolean isComplete() {
    return complete.get();
  }
}
