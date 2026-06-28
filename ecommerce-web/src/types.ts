export type Product = {
  productId: string;
  productDescription: string;
  productPrice: number;
  productPicture: string;
  /** Units in stock (from product-service; optional for older responses). */
  stock?: number;
};

export type CartLineItem = {
  productId: string;
  productDescription: string;
  productPrice: number;
  productPicture: string;
  quantity: number;
};

export type CartResponse = {
  lineItems: CartLineItem[];
  total: number;
};

export type PayResponse = {
  status: string;
  message: string;
};
