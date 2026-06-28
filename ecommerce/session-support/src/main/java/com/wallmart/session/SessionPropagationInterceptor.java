package com.wallmart.session;

import java.io.IOException;
import org.springframework.http.HttpRequest;
import org.springframework.http.client.ClientHttpRequestExecution;
import org.springframework.http.client.ClientHttpRequestInterceptor;
import org.springframework.http.client.ClientHttpResponse;
import org.springframework.stereotype.Component;

@Component
public class SessionPropagationInterceptor implements ClientHttpRequestInterceptor {

  @Override
  public ClientHttpResponse intercept(
      HttpRequest request, byte[] body, ClientHttpRequestExecution execution) throws IOException {
    SessionInfo info = SessionContext.get();
    if (info != null) {
      request.getHeaders().set(SessionHeaders.SESSION_ID, info.sessionId());
      request.getHeaders().set(SessionHeaders.SESSION_USERNAME, info.username());
    }
    return execution.execute(request, body);
  }
}
