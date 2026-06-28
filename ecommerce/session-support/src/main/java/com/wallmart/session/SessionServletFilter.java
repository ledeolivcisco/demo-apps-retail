package com.wallmart.session;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.http.MediaType;
import org.springframework.web.filter.OncePerRequestFilter;

public class SessionServletFilter extends OncePerRequestFilter {

  private static final Logger log = LoggerFactory.getLogger(SessionServletFilter.class);

  private static final String MDC_SESSION_ID = "sessionId";
  private static final String MDC_SESSION_USERNAME = "sessionUsername";

  @Override
  protected boolean shouldNotFilter(HttpServletRequest request) {
    String path = request.getRequestURI();
    return path != null
        && (path.startsWith("/actuator") || path.startsWith("/internal/demo"));
  }

  @Override
  protected void doFilterInternal(
      HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
      throws ServletException, IOException {
    String sessionId = request.getHeader(SessionHeaders.SESSION_ID);
    String username = request.getHeader(SessionHeaders.SESSION_USERNAME);

    if (sessionId == null || sessionId.isBlank() || username == null || username.isBlank()) {
      log.warn(
          "event=session.request.rejected path={} reason=missing_headers",
          request.getRequestURI());
      response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
      response.setContentType(MediaType.APPLICATION_JSON_VALUE);
      response
          .getWriter()
          .write(
              "{\"message\":\"Missing or blank "
                  + SessionHeaders.SESSION_ID
                  + " or "
                  + SessionHeaders.SESSION_USERNAME
                  + "\"}");
      return;
    }

    SessionInfo info = new SessionInfo(sessionId.trim(), username.trim());
    SessionContext.set(info);
    MDC.put(MDC_SESSION_ID, info.sessionId());
    MDC.put(MDC_SESSION_USERNAME, info.username());
    response.setHeader(SessionHeaders.SESSION_ID, info.sessionId());
    response.setHeader(SessionHeaders.SESSION_USERNAME, info.username());

    try {
      filterChain.doFilter(request, response);
    } finally {
      MDC.remove(MDC_SESSION_ID);
      MDC.remove(MDC_SESSION_USERNAME);
      SessionContext.clear();
    }
  }
}
