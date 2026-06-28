/**
 * Splunk Observability Cloud — Browser RUM for this React SPA.
 *
 * @see https://help.splunk.com/en/splunk-observability-cloud/manage-data/instrument-front-end-applications/instrument-mobile-and-web-applications-for-splunk-rum/instrument-browser-applications-for-splunk-rum/install-the-splunk-rum-browser-agent
 */

let splunkRumInitStarted = false;

export async function initSplunkRum(): Promise<void> {
  if (splunkRumInitStarted) return;

  const realm = import.meta.env.VITE_SPLUNK_REALM?.trim();
  const rumAccessToken = import.meta.env.VITE_SPLUNK_RUM_ACCESS_TOKEN?.trim();

  if (!realm || !rumAccessToken) {
    console.warn(
      "[Splunk Browser RUM] VITE_OBSERVABILITY_BACKEND is splunk but VITE_SPLUNK_REALM or VITE_SPLUNK_RUM_ACCESS_TOKEN is empty, so the RUM agent will not load. " +
        "Create a RUM access token in Observability Cloud (Settings → Access Tokens → RUM) and set vars in ecommerce-web/.env.local or docker/.env for production builds.",
    );
    return;
  }

  splunkRumInitStarted = true;

  const { SplunkRum } = await import("@splunk/otel-web");

  const spaMetrics = import.meta.env.VITE_SPLUNK_SPA_METRICS !== "false";

  SplunkRum.init({
    realm,
    rumAccessToken,
    applicationName: import.meta.env.VITE_SPLUNK_APPLICATION_NAME?.trim() || "ecommerce-web",
    deploymentEnvironment:
      import.meta.env.VITE_SPLUNK_DEPLOYMENT_ENVIRONMENT?.trim() || "dev",
    spaMetrics,
  });
}
