import { expect, test } from "@playwright/test";
import { addProduct } from "./support/productCard";
import { syntheticPace } from "./support/syntheticPace";

test.describe("FreshMart checkout product 2", () => {
  test("checkout Whole Milk 1 gal", async ({ page }) => {
    test.setTimeout(120_000);
    await page.goto("/");

    await syntheticPace(2000);
    await addProduct(page, "Whole Milk 1 gal");
    await expect(page.getByText("Added", { exact: true })).toBeVisible();

    await page.getByRole("link", { name: "Open shopping cart" }).click();
    await expect(page.getByRole("button", { name: "Pay" })).toBeEnabled();

    await syntheticPace(3000);
    await page.getByRole("button", { name: "Pay" }).click();

    await expect(page).toHaveURL(/\/payment$/);
    await expect(page.getByText("Payment successful")).toBeVisible({ timeout: 45_000 });
    await expect(page.getByText(/Amount sent:\s*\$4\.29/)).toBeVisible();

    await syntheticPace(4000);
  });
});
