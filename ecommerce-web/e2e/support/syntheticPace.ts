/** Synthetic pacing delay; shorter when PLAYWRIGHT_SYNTHETIC_PACE_MS is set (Docker loop). */
export async function syntheticPace(defaultMs: number): Promise<void> {
  const override = process.env.PLAYWRIGHT_SYNTHETIC_PACE_MS;
  const ms = override !== undefined && override !== "" ? Number(override) : defaultMs;
  if (Number.isFinite(ms) && ms > 0) {
    await new Promise<void>((resolve) => setTimeout(resolve, ms));
  }
}
