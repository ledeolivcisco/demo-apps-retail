DROP TABLE IF EXISTS payment_transaction;
DROP TABLE IF EXISTS cart_line;
DROP TABLE IF EXISTS inventory;
DROP TABLE IF EXISTS products;

CREATE TABLE products (
  product_id          VARCHAR(10)   NOT NULL PRIMARY KEY,
  product_description NVARCHAR(200) NOT NULL,
  product_price       DECIMAL(10,2) NOT NULL,
  product_picture     NVARCHAR(500) NOT NULL
);

CREATE TABLE inventory (
  product_id VARCHAR(10) NOT NULL PRIMARY KEY,
  stock      INT NOT NULL CHECK (stock >= 0),
  FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE cart_line (
  session_id VARCHAR(36) NOT NULL,
  product_id VARCHAR(10) NOT NULL,
  quantity   INT NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (session_id, product_id),
  FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE payment_transaction (
  transaction_id BIGINT IDENTITY(1,1) PRIMARY KEY,
  session_id     VARCHAR(36) NOT NULL,
  username       NVARCHAR(100) NOT NULL,
  amount         DECIMAL(10,2) NOT NULL,
  status         NVARCHAR(20) NOT NULL,
  message        NVARCHAR(500),
  created_at     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
