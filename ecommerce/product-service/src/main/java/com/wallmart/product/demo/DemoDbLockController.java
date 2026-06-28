package com.wallmart.product.demo;

import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/internal/demo/db-lock")
public class DemoDbLockController {

  private static final Logger log = LoggerFactory.getLogger(DemoDbLockController.class);

  private final InventoryDemoLockService lockService;
  private final boolean chaosEnabled;

  public DemoDbLockController(
      InventoryDemoLockService lockService,
      @Value("${WALLMART_DEMO_CHAOS_ENABLED:false}") boolean chaosEnabled) {
    this.lockService = lockService;
    this.chaosEnabled = chaosEnabled;
  }

  @PostMapping("/inventory")
  public ResponseEntity<Map<String, Object>> lockInventory(
      @RequestParam(defaultValue = "60") int seconds,
      @RequestParam(defaultValue = "table") String mode) {
    if (!chaosEnabled) {
      return ResponseEntity.notFound().build();
    }
    if (seconds < 5 || seconds > 300) {
      return ResponseEntity.badRequest()
          .body(Map.of("message", "seconds must be between 5 and 300"));
    }
    if (!"table".equals(mode) && !"row".equals(mode)) {
      return ResponseEntity.badRequest().body(Map.of("message", "mode must be 'table' or 'row'"));
    }
    if (!lockService.tryStartLock()) {
      return ResponseEntity.status(HttpStatus.CONFLICT)
          .body(Map.of("message", "An inventory demo lock is already active"));
    }

    Thread lockThread =
        new Thread(
            () -> {
              try {
                lockService.holdInventoryLock(seconds, mode);
              } catch (Exception e) {
                log.error("event=demo.db_lock.failed mode={} seconds={}", mode, seconds, e);
              } finally {
                lockService.clearLockActive();
              }
            },
            "demo-inventory-lock");
    lockThread.setDaemon(true);
    lockThread.start();

    return ResponseEntity.status(HttpStatus.ACCEPTED)
        .body(
            Map.of(
                "message",
                "Inventory demo lock started",
                "seconds",
                seconds,
                "mode",
                mode));
  }
}
