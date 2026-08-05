/** Timeouts for E2E flows that call AWS pricing / credit-validation lambdas. */
export const LAMBDA_E2E = {
  test: 180_000,
  catalogLoad: 90_000,
  checkout: 60_000,
} as const;
