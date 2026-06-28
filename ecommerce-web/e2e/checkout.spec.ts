import { expect, test } from "@playwright/test";
import { addProduct } from "./support/productCard";
import { syntheticPace } from "./support/syntheticPace";

test.describe("FreshMart checkout", () => {
  test("checkout: cart → pay → payment success (inventory + payment orchestration)", async ({
    page,
  }) => {
    test.setTimeout(120_000);
    await page.goto("/");

    await syntheticPace(2000);
    await addProduct(page, "Whole Wheat Bread");
    await expect(page.getByText("Added", { exact: true })).toBeVisible();

    await page.getByRole("link", { name: "Open shopping cart" }).click();
    await expect(page.getByRole("button", { name: "Pay" })).toBeEnabled();

    await syntheticPace(3000);
    await page.getByRole("button", { name: "Pay" }).click();

    await expect(page).toHaveURL(/\/payment$/);
    await expect(page.getByRole("heading", { name: "Payment", level: 1 })).toBeVisible();
    await syntheticPace(3000);
    await expect(page.getByText("Payment successful")).toBeVisible({ timeout: 45_000 });
    await expect(page.getByText(/Amount sent:\s*\$3\.49/)).toBeVisible();

    await expect(page.getByRole("link", { name: "Continue shopping" })).toBeVisible();

    await syntheticPace(4000);
  });
});
