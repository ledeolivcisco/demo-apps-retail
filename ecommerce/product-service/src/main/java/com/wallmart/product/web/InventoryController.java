package com.wallmart.product.web;

import com.wallmart.product.catalog.JdbcProductCatalog;
import com.wallmart.product.inventory.InsufficientStockException;
import com.wallmart.product.inventory.InventoryLine;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/internal/inventory")
public class InventoryController {

  private final JdbcProductCatalog catalog;

  public InventoryController(JdbcProductCatalog catalog) {
    this.catalog = catalog;
  }

  @PostMapping("/deduct")
  public ResponseEntity<?> deduct(@RequestBody List<InventoryLine> lines) {
    if (lines == null || lines.isEmpty()) {
      return ResponseEntity.badRequest().body(Map.of("message", "At least one inventory line is required"));
    }
    try {
      catalog.applyDeduction(lines);
      return ResponseEntity.noContent().build();
    } catch (InsufficientStockException e) {
      return ResponseEntity.status(HttpStatus.CONFLICT).body(Map.of("message", e.getMessage()));
    } catch (IllegalArgumentException e) {
      return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
    }
  }

  @PostMapping("/restore")
  public ResponseEntity<Void> restore(@RequestBody List<InventoryLine> lines) {
    if (lines != null && !lines.isEmpty()) {
      catalog.applyRestore(lines);
    }
    return ResponseEntity.noContent().build();
  }
}
