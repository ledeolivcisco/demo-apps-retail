import type { Page } from "@playwright/test";

export function productCard(page: Page, productName: string) {
  return page.locator("article.product-card").filter({
    has: page.getByRole("heading", { name: productName, level: 2 }),
  });
}

export async function addProduct(page: Page, productName: string): Promise<void> {
  await productCard(page, productName).getByRole("button", { name: "Add to cart" }).click();
}

export function firstProductCard(page: Page) {
  return page.locator("article.product-card").first();
}

export async function addFirstProduct(
  page: Page,
): Promise<{ name: string; price: string }> {
  const card = firstProductCard(page);
  const name = (await card.getByRole("heading", { level: 2 }).textContent()) ?? "";
  const price = (await card.locator(".product-price").textContent()) ?? "";
  await card.getByRole("button", { name: "Add to cart" }).click();
  return { name, price };
}
