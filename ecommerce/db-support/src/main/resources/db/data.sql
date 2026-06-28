INSERT INTO products (product_id, product_description, product_price, product_picture) VALUES
  ('1',  'Whole Wheat Bread',   3.49, 'https://picsum.photos/seed/wallmart-bread/200/200'),
  ('2',  'Whole Milk 1 gal',  4.29, 'https://picsum.photos/seed/wallmart-milk/200/200'),
  ('3',  'Large Eggs 12 ct',    3.99, 'https://picsum.photos/seed/wallmart-eggs/200/200'),
  ('4',  'Bananas (per lb)',    0.59, 'https://picsum.photos/seed/wallmart-banana/200/200'),
  ('5',  'Ground Beef 1 lb',   6.99, 'https://picsum.photos/seed/wallmart-beef/200/200'),
  ('6',  'Cheddar Cheese 8 oz', 3.79, 'https://picsum.photos/seed/wallmart-cheese/200/200'),
  ('7',  'Orange Juice 64 oz',  4.49, 'https://picsum.photos/seed/wallmart-oj/200/200'),
  ('8',  'Pasta 16 oz',         1.29, 'https://picsum.photos/seed/wallmart-pasta/200/200'),
  ('9',  'Tomatoes 1 lb',       2.49, 'https://picsum.photos/seed/wallmart-tomato/200/200'),
  ('10', 'Butter 1 lb',         4.99, 'https://picsum.photos/seed/wallmart-butter/200/200');

INSERT INTO inventory (product_id, stock) VALUES
  ('1', 999), ('2', 999), ('3', 999), ('4', 999), ('5', 999),
  ('6', 999), ('7', 999), ('8', 999), ('9', 999), ('10', 999);
