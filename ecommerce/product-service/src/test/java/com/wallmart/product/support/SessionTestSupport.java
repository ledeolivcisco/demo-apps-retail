package com.wallmart.product.support;

import com.wallmart.session.SessionHeaders;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

public final class SessionTestSupport {

  public static final String SESSION_ID = "test-session-1";
  public static final String USERNAME = "test_user_alpha";

  private SessionTestSupport() {}

  public static MockHttpServletRequestBuilder withSession(MockHttpServletRequestBuilder builder) {
    return builder
        .header(SessionHeaders.SESSION_ID, SESSION_ID)
        .header(SessionHeaders.SESSION_USERNAME, USERNAME);
  }
}
