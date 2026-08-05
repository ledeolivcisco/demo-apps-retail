-- Idempotent upgrades for existing databases (safe to re-run).
IF COL_LENGTH('cart_line', 'unit_price') IS NULL
  ALTER TABLE cart_line ADD unit_price DECIMAL(10,2) NULL;
