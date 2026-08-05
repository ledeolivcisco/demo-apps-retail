import { expect, test } from "@playwright/test";
import { LAMBDA_E2E } from "./support/lambdaTimeouts";
import { addFirstProduct, firstProductCard } from "./support/productCard";
import { syntheticPace } from "./support/syntheticPace";

test.describe("FreshMart appliance checkout", () => {
  test("checkout: first appliance → cart → pay → payment success", async ({ page }) => {
    test.setTimeout(LAMBDA_E2E.test);
    await page.goto("/appliances");

    await expect(page.getByRole("heading", { name: "Shop appliances" })).toBeVisible();
    await expect(page.getByText("Loading appliances…")).toBeHidden({
      timeout: LAMBDA_E2E.catalogLoad,
    });
    await expect(firstProductCard(page)).toBeVisible();

    await syntheticPace(2000);
    const { name, price } = await addFirstProduct(page);
    await expect(page.getByText("Added", { exact: true })).toBeVisible();

    await page.getByRole("link", { name: "Open shopping cart" }).click();
    await expect(page.getByRole("listitem").filter({ hasText: name })).toBeVisible();
    await expect(page.locator(".cart-total-row strong")).toHaveText(price);
    await expect(page.getByRole("button", { name: "Pay" })).toBeEnabled();

    await syntheticPace(3000);
    await page.getByRole("button", { name: "Pay" }).click();

    await expect(page).toHaveURL(/\/payment$/);
    await expect(page.getByRole("heading", { name: "Payment", level: 1 })).toBeVisible();
    await syntheticPace(3000);
    await expect(page.getByText("Processing checkout…")).toBeHidden({
      timeout: LAMBDA_E2E.checkout,
    });
    await expect(page.getByText("Payment successful")).toBeVisible({
      timeout: LAMBDA_E2E.checkout,
    });
    await expect(page.getByText(`Amount sent: ${price}`)).toBeVisible();

    await expect(page.getByRole("link", { name: "Continue shopping" })).toBeVisible();

    await syntheticPace(4000);
  });
});
