package com.wallmart.session;

import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

@Component
public class SessionRegistry {

  private static final Logger log = LoggerFactory.getLogger(SessionRegistry.class);

  private final ConcurrentMap<String, SessionRecord> sessions = new ConcurrentHashMap<>();

  public void open(SessionInfo info) {
    try {
      sessions.compute(
          info.sessionId(),
          (id, existing) -> {
            if (existing != null && existing.state() == SessionState.COMPLETED) {
              throw new SessionNotActiveException("Session already completed: " + id);
            }
            return new SessionRecord(info.sessionId(), info.username(), SessionState.ACTIVE);
          });
      log.info(
          "event=session.opened sessionId={} username={}", info.sessionId(), info.username());
    } catch (SessionNotActiveException e) {
      log.warn("event=session.already_completed sessionId={}", info.sessionId());
      throw e;
    }
  }

  public void close(String sessionId) {
    sessions.computeIfPresent(
        sessionId,
        (id, existing) ->
            new SessionRecord(existing.sessionId(), existing.username(), SessionState.COMPLETED));
    log.info("event=session.completed sessionId={}", sessionId);
  }

  public void requireActive(String sessionId) {
    SessionRecord record = sessions.get(sessionId);
    if (record != null && record.state() == SessionState.COMPLETED) {
      log.warn("event=session.not_active sessionId={} reason=completed", sessionId);
      throw new SessionNotActiveException("Session is not active: " + sessionId);
    }
  }

  public Optional<SessionRecord> find(String sessionId) {
    return Optional.ofNullable(sessions.get(sessionId));
  }

  void clear() {
    sessions.clear();
  }
}
