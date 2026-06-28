package com.wallmart.session;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import java.io.IOException;
import java.net.URI;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.mock.http.client.MockClientHttpRequest;
import org.springframework.mock.http.client.MockClientHttpResponse;

class SessionPropagationInterceptorTest {

  private final SessionPropagationInterceptor interceptor = new SessionPropagationInterceptor();

  @AfterEach
  void tearDown() {
    SessionContext.clear();
  }

  @Test
  @DisplayName("Interceptor forwards both session headers when context is set")
  void intercept_forwardsSessionHeaders() throws IOException {
    SessionContext.set(new SessionInfo("session-abc", "brisk_otter_1234"));
    MockClientHttpRequest request = new MockClientHttpRequest(HttpMethod.POST, URI.create("/pay"));

    interceptor.intercept(
        request,
        new byte[0],
        (httpRequest, body) -> {
          assertEquals("session-abc", httpRequest.getHeaders().getFirst(SessionHeaders.SESSION_ID));
          assertEquals(
              "brisk_otter_1234",
              httpRequest.getHeaders().getFirst(SessionHeaders.SESSION_USERNAME));
          return new MockClientHttpResponse(new byte[0], HttpStatus.OK);
        });
  }

  @Test
  @DisplayName("Interceptor leaves request unchanged when context is empty")
  void intercept_withoutContext_doesNotAddHeaders() throws IOException {
    MockClientHttpRequest request = new MockClientHttpRequest(HttpMethod.POST, URI.create("/pay"));

    interceptor.intercept(
        request,
        new byte[0],
        (httpRequest, body) -> {
          assertNull(httpRequest.getHeaders().getFirst(SessionHeaders.SESSION_ID));
          assertNull(httpRequest.getHeaders().getFirst(SessionHeaders.SESSION_USERNAME));
          return new MockClientHttpResponse(new byte[0], HttpStatus.OK);
        });
  }
}
