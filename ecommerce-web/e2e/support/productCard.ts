import type { Page } from "@playwright/test";

export function productCard(page: Page, productName: string) {
  return page.locator("article.product-card").filter({
    has: page.getByRole("heading", { name: productName, level: 2 }),
  });
}

export async function addProduct(page: Page, productName: string): Promise<void> {
  await productCard(page, productName).getByRole("button", { name: "Add to cart" }).click();
}
