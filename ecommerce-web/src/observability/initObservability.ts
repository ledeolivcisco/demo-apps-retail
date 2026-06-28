/**
 * Frontend RUM dispatcher — exactly one backend: AppDynamics Browser RUM or Splunk Browser RUM.
 *
 * Set `VITE_OBSERVABILITY_BACKEND` to `appdynamics`, `splunk`, or `none`.
 * When unset, falls back to legacy `VITE_APPDYNAMICS_ENABLED=true` → AppDynamics.
 */

import { initAppDynamics } from "@/appdynamics/initAppDynamics";

export type ObservabilityBackend = "appdynamics" | "splunk" | "none";

function envTruthy(v: string | boolean | undefined): boolean {
  if (typeof v === "boolean") return v;
  return (v ?? "").trim().toLowerCase() === "true";
}

function resolveBackend(): ObservabilityBackend {
  const explicit = import.meta.env.VITE_OBSERVABILITY_BACKEND?.trim().toLowerCase();
  if (explicit === "appdynamics" || explicit === "splunk" || explicit === "none") {
    return explicit;
  }
  if (envTruthy(import.meta.env.VITE_APPDYNAMICS_ENABLED)) {
    return "appdynamics";
  }
  return "none";
}

/**
 * Initialize browser RUM before React mounts. Must complete before `createRoot()`.
 */
export async function initObservability(): Promise<void> {
  const backend = resolveBackend();

  if (backend === "appdynamics") {
    initAppDynamics({ force: true });
    return;
  }

  if (backend === "splunk") {
    const { initSplunkRum } = await import("@/observability/initSplunkRum");
    await initSplunkRum();
    return;
  }
}
