package com.wallmart.cart.support;

import com.wallmart.session.SessionHeaders;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

public final class SessionTestSupport {

  public static final String SESSION_ID = "test-session-1";
  public static final String USERNAME = "test_user_alpha";
  public static final String OTHER_SESSION_ID = "test-session-2";
  public static final String OTHER_USERNAME = "test_user_beta";

  private SessionTestSupport() {}

  public static MockHttpServletRequestBuilder withSession(MockHttpServletRequestBuilder builder) {
    return builder
        .header(SessionHeaders.SESSION_ID, SESSION_ID)
        .header(SessionHeaders.SESSION_USERNAME, USERNAME);
  }

  public static MockHttpServletRequestBuilder withSession(
      MockHttpServletRequestBuilder builder, String sessionId, String username) {
    return builder
        .header(SessionHeaders.SESSION_ID, sessionId)
        .header(SessionHeaders.SESSION_USERNAME, username);
  }
}
