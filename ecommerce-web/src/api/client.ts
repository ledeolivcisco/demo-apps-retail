import type { Appliance, ApplianceType, CartResponse, PayResponse, Product } from "@/types";
import { ensureSession } from "@/session/shoppingSession";

const SESSION_ID_HEADER = "X-Session-Id";
const SESSION_USERNAME_HEADER = "X-Session-Username";

function apiUrl(path: string): string {
  const base = import.meta.env.VITE_API_BASE_URL ?? "";
  return `${base.replace(/\/$/, "")}${path}`;
}

function sessionHeaders(): Record<string, string> {
  const session = ensureSession();
  return {
    [SESSION_ID_HEADER]: session.sessionId,
    [SESSION_USERNAME_HEADER]: session.username,
  };
}

function withSessionHeaders(headers: Record<string, string> = {}): Record<string, string> {
  return { ...sessionHeaders(), ...headers };
}

async function parseJson<T>(res: Response): Promise<T> {
  const text = await res.text();
  if (!text) {
    throw new Error(`Empty response (${res.status})`);
  }
  return JSON.parse(text) as T;
}

export async function fetchProducts(): Promise<Product[]> {
  const res = await fetch(apiUrl("/productsearch"), {
    headers: withSessionHeaders({ Accept: "application/json" }),
  });
  if (!res.ok) {
    throw new Error(`Failed to load products (${res.status})`);
  }
  return parseJson<Product[]>(res);
}

type GraphQlResponse<T> = {
  data?: T;
  errors?: { message: string }[];
};

async function graphQlRequest<T>(
  query: string,
  variables?: Record<string, unknown>,
): Promise<T> {
  const res = await fetch(apiUrl("/graphql"), {
    method: "POST",
    headers: withSessionHeaders({
      Accept: "application/json",
      "Content-Type": "application/json",
    }),
    body: JSON.stringify({ query, variables }),
  });
  if (!res.ok) {
    throw new Error(`GraphQL request failed (${res.status})`);
  }
  const body = await parseJson<GraphQlResponse<T>>(res);
  if (body.errors?.length) {
    throw new Error(body.errors[0].message);
  }
  if (body.data === undefined) {
    throw new Error("GraphQL response missing data");
  }
  return body.data;
}

const APPLIANCES_QUERY = `
  query Appliances($type: ApplianceType, $search: String) {
    appliances(type: $type, search: $search) {
      applianceId
      applianceType
      applianceDescription
      appliancePrice
      appliancePicture
      stock
    }
  }
`;

export async function fetchAppliances(
  type?: ApplianceType,
  search?: string,
): Promise<Appliance[]> {
  const data = await graphQlRequest<{ appliances: Appliance[] }>(APPLIANCES_QUERY, {
    type: type ?? null,
    search: search ?? null,
  });
  return data.appliances;
}

export async function addApplianceToCart(
  applianceId: string,
  price?: number,
): Promise<void> {
  const params = price != null ? `?price=${encodeURIComponent(String(price))}` : "";
  const res = await fetch(apiUrl(`/addappliance/${encodeURIComponent(applianceId)}${params}`), {
    method: "POST",
    headers: withSessionHeaders({ Accept: "application/json" }),
  });
  if (res.status === 404) {
    const body = await parseJson<{ message?: string }>(res).catch(
      (): { message?: string } => ({}),
    );
    throw new Error(body.message ?? "Appliance not found");
  }
  if (!res.ok) {
    throw new Error(`Could not add to cart (${res.status})`);
  }
}

export async function addProductToCart(productId: string): Promise<void> {
  const res = await fetch(apiUrl(`/addproduct/${encodeURIComponent(productId)}`), {
    method: "POST",
    headers: withSessionHeaders({ Accept: "application/json" }),
  });
  if (res.status === 404) {
    const body = await parseJson<{ message?: string }>(res).catch(
      (): { message?: string } => ({}),
    );
    throw new Error(body.message ?? "Product not found");
  }
  if (!res.ok) {
    throw new Error(`Could not add to cart (${res.status})`);
  }
}

export async function fetchCart(): Promise<CartResponse> {
  const res = await fetch(apiUrl("/getcart"), {
    headers: withSessionHeaders({ Accept: "application/json" }),
  });
  if (!res.ok) {
    throw new Error(`Failed to load cart (${res.status})`);
  }
  return parseJson<CartResponse>(res);
}

/** Clears server-side cart (cart-service). */
export async function clearCart(): Promise<void> {
  const res = await fetch(apiUrl("/clearcart"), {
    method: "DELETE",
    headers: withSessionHeaders({ Accept: "application/json" }),
  });
  if (!res.ok) {
    throw new Error(`Failed to clear cart (${res.status})`);
  }
}

/**
 * Checkout via cart-service: deducts inventory (product-service), confirms payment
 * (payment-service), then clears the server cart.
 */
export async function submitCheckout(value: number): Promise<PayResponse> {
  const res = await fetch(apiUrl("/checkout"), {
    method: "POST",
    headers: withSessionHeaders({
      Accept: "application/json",
      "Content-Type": "application/json",
    }),
    body: JSON.stringify({ value }),
  });
  if (!res.ok) {
    const body = await parseJson<{ message?: string }>(res).catch(
      (): { message?: string } => ({}),
    );
    throw new Error(body.message ?? `Checkout failed (${res.status})`);
  }
  return parseJson<PayResponse>(res);
}
