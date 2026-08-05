export type Product = {
  productId: string;
  productDescription: string;
  productPrice: number;
  productPicture: string;
  /** Units in stock (from product-service; optional for older responses). */
  stock?: number;
};

export type ApplianceType = "FRIDGE" | "OVEN" | "WASHING_MACHINE";

export type Appliance = {
  applianceId: string;
  applianceType: ApplianceType;
  applianceDescription: string;
  appliancePrice: number;
  appliancePicture: string;
  stock: number;
};

export type CartLineItem = {
  itemType: "PRODUCT" | "APPLIANCE";
  itemId: string;
  description: string;
  price: number;
  picture: string;
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
