import { expect, test } from "@playwright/test";
import { addProduct } from "./support/productCard";
import { syntheticPace } from "./support/syntheticPace";

test.describe.configure({ mode: "parallel" });

test.describe("FreshMart cart", () => {
  test("user can add an item and see it on the cart page", async ({ page }) => {
    test.setTimeout(90_000);
    await page.goto("/");

    await syntheticPace(2000);
    await addProduct(page, "Whole Wheat Bread");
    await expect(page.getByText("Added", { exact: true })).toBeVisible();

    await syntheticPace(2000);
    await page.getByRole("link", { name: "Open shopping cart" }).click();
    await expect(page).toHaveURL(/\/cart$/);
    await syntheticPace(4000);
    await expect(page.getByRole("heading", { name: "Your cart", level: 1 })).toBeVisible();
    const row = page.getByRole("listitem").filter({ hasText: "Whole Wheat Bread" });
    await expect(row).toBeVisible();
    await expect(row.getByText("$3.49 × 1")).toBeVisible();
    await syntheticPace(4000);
  });

  test("cart badge shows item count after add", async ({ page }) => {
    test.setTimeout(90_000);
    await page.goto("/");

    await syntheticPace(2000);
    await addProduct(page, "Whole Wheat Bread");
    await expect(page.getByText("Added", { exact: true })).toBeVisible();

    await expect(page.locator(".cart-badge")).toHaveText("1");
    await syntheticPace(4000);
  });
});
