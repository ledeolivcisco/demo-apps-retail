package com.wallmart.product.web;

import com.wallmart.product.catalog.JdbcProductCatalog;
import com.wallmart.product.model.Product;
import com.wallmart.session.SessionContext;
import com.wallmart.session.SessionRegistry;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class ProductController {

  private static final Logger log = LoggerFactory.getLogger(ProductController.class);

  private final JdbcProductCatalog catalog;
  private final SessionRegistry sessionRegistry;

  public ProductController(JdbcProductCatalog catalog, SessionRegistry sessionRegistry) {
    this.catalog = catalog;
    this.sessionRegistry = sessionRegistry;
  }

  @GetMapping("/productsearch")
  public ResponseEntity<List<Product>> productSearch() {
    sessionRegistry.open(SessionContext.require());
    List<Product> products = catalog.allProducts();
    log.info("event=catalog.browsed productCount={}", products.size());
    return ResponseEntity.ok(products);
  }
}
