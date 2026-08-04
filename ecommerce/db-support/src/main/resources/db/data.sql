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

INSERT INTO appliances (appliance_id, appliance_type, appliance_description, appliance_price, appliance_picture) VALUES
  ('A1', 'FRIDGE', 'French Door Refrigerator 28 cu ft', 1299.99, 'https://picsum.photos/seed/wallmart-fridge1/200/200'),
  ('A2', 'FRIDGE', 'Top Freezer Refrigerator 18 cu ft', 699.99, 'https://picsum.photos/seed/wallmart-fridge2/200/200'),
  ('A3', 'FRIDGE', 'Mini Fridge 4.5 cu ft', 189.99, 'https://picsum.photos/seed/wallmart-fridge3/200/200'),
  ('A4', 'OVEN', 'Electric Single Wall Oven 30"', 899.99, 'https://picsum.photos/seed/wallmart-oven1/200/200'),
  ('A5', 'OVEN', 'Gas Range 5 Burner 30"', 749.99, 'https://picsum.photos/seed/wallmart-oven2/200/200'),
  ('A6', 'OVEN', 'Convection Toaster Oven XL', 149.99, 'https://picsum.photos/seed/wallmart-oven3/200/200'),
  ('A7', 'WASHING_MACHINE', 'Front Load Washer 4.5 cu ft', 799.99, 'https://picsum.photos/seed/wallmart-washer1/200/200'),
  ('A8', 'WASHING_MACHINE', 'Top Load Washer 5.0 cu ft', 649.99, 'https://picsum.photos/seed/wallmart-washer2/200/200'),
  ('A9', 'WASHING_MACHINE', 'Compact Portable Washer', 299.99, 'https://picsum.photos/seed/wallmart-washer3/200/200');

INSERT INTO appliance_inventory (appliance_id, stock) VALUES
  ('A1', 50), ('A2', 40), ('A3', 100),
  ('A4', 25), ('A5', 30), ('A6', 75),
  ('A7', 35), ('A8', 45), ('A9', 60);
