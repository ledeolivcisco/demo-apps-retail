import { expect, test } from "@playwright/test";
import { syntheticPace } from "./support/syntheticPace";

test.describe("FreshMart browse", () => {
  test("browse catalog without adding to cart", async ({ page }) => {
    test.setTimeout(60_000);
    await page.goto("/");

    await expect(page.getByRole("heading", { name: "Shop the aisles", level: 1 })).toBeVisible();
    await expect(page.getByRole("heading", { name: "Large Eggs 12 ct", level: 2 })).toBeVisible();

    await page.getByRole("heading", { name: "Large Eggs 12 ct", level: 2 }).scrollIntoViewIfNeeded();
    await syntheticPace(2000);

    await expect(page.getByRole("heading", { name: "Butter 1 lb", level: 2 })).toBeVisible();
    await expect(page.locator(".cart-badge")).toHaveCount(0);

    await syntheticPace(2000);
  });
});
