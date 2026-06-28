import { expect, test } from "@playwright/test";

test.describe("FreshMart catalog", () => {
  test("home page loads the product catalog", async ({ page }) => {
    await page.goto("/");

    await expect(page.getByRole("heading", { name: "Shop the aisles", level: 1 })).toBeVisible();
    await expect(
      page.getByText("Everyday staples delivered from our mock supermarket backends."),
    ).toBeVisible();

    const addButtons = page.getByRole("button", { name: "Add to cart" });
    await expect(addButtons.first()).toBeVisible();
    await expect(addButtons).toHaveCount(10);

    await expect(page.getByRole("heading", { name: "Whole Wheat Bread", level: 2 })).toBeVisible();
  });
});
