import { expect, test } from "@playwright/test";
import { addProduct } from "./support/productCard";
import { syntheticPace } from "./support/syntheticPace";

test.describe("FreshMart multi-item cart", () => {
  test("add two products and verify cart total", async ({ page }) => {
    test.setTimeout(90_000);
    await page.goto("/");

    await syntheticPace(2000);
    await addProduct(page, "Whole Wheat Bread");
    await expect(page.getByText("Added", { exact: true })).toBeVisible();

    await syntheticPace(1000);
    await addProduct(page, "Whole Milk 1 gal");
    await expect(page.getByText("Added", { exact: true })).toBeVisible();

    await page.getByRole("link", { name: "Open shopping cart" }).click();
    await expect(page).toHaveURL(/\/cart$/);
    await expect(page.getByRole("heading", { name: "Your cart", level: 1 })).toBeVisible();

    await expect(page.getByRole("listitem").filter({ hasText: "Whole Wheat Bread" })).toBeVisible();
    await expect(page.getByRole("listitem").filter({ hasText: "Whole Milk 1 gal" })).toBeVisible();
    await expect(page.locator(".cart-total-row strong")).toHaveText("$7.78");

    await syntheticPace(4000);
  });
});
