import { expect, test } from "@playwright/test";
import { addProduct } from "./support/productCard";
import { syntheticPace } from "./support/syntheticPace";

test.describe("FreshMart abandon cart", () => {
  test("user abandons cart before checkout", async ({ page }) => {
    test.setTimeout(90_000);
    await page.goto("/");

    await syntheticPace(2000);
    await addProduct(page, "Whole Wheat Bread");
    await expect(page.getByText("Added", { exact: true })).toBeVisible();

    await page.getByRole("link", { name: "Open shopping cart" }).click();
    await expect(page).toHaveURL(/\/cart$/);
    await expect(page.getByRole("heading", { name: "Your cart", level: 1 })).toBeVisible();
    await expect(page.getByRole("button", { name: "Pay" })).toBeEnabled();

    await syntheticPace(2000);
    await page.getByRole("link", { name: "FreshMart" }).click();
    await expect(page).toHaveURL(/\/$/);
    await expect(page.getByRole("heading", { name: "Shop the aisles", level: 1 })).toBeVisible();
    await expect(page.getByText("Payment successful")).not.toBeVisible();
    await expect(page.locator(".cart-badge")).toHaveText("1");

    await syntheticPace(4000);
  });
});
