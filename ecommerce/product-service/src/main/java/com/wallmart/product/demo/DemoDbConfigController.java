package com.wallmart.product.demo;

import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/internal/demo/db-config")
public class DemoDbConfigController {

  private final SqlServerConfigDemoService configService;
  private final boolean chaosEnabled;

  public DemoDbConfigController(
      SqlServerConfigDemoService configService,
      @Value("${WALLMART_DEMO_CHAOS_ENABLED:false}") boolean chaosEnabled) {
    this.configService = configService;
    this.chaosEnabled = chaosEnabled;
  }

  @PostMapping("/blocked-process-threshold")
  public ResponseEntity<Map<String, Object>> setBlockedProcessThreshold(
      @RequestParam int seconds) {
    if (!chaosEnabled) {
      return ResponseEntity.notFound().build();
    }
    if (seconds < 5 || seconds > 300) {
      return ResponseEntity.badRequest()
          .body(Map.of("message", "seconds must be between 5 and 300"));
    }
    int previous = configService.setBlockedProcessThreshold(seconds);
    return ResponseEntity.ok(
        Map.of(
            "message",
            "Blocked process threshold updated",
            "seconds",
            seconds,
            "previous",
            previous));
  }

  @PostMapping("/blocked-process-threshold/restore")
  public ResponseEntity<Map<String, Object>> restoreBlockedProcessThreshold() {
    if (!chaosEnabled) {
      return ResponseEntity.notFound().build();
    }
    int previous = configService.restoreBlockedProcessThreshold();
    return ResponseEntity.ok(
        Map.of(
            "message",
            "Blocked process threshold restored (disabled)",
            "seconds",
            0,
            "previous",
            previous));
  }
}
