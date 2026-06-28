/**
 * Splunk AppDynamics — Browser Real User Monitoring (JavaScript agent) for this React SPA.
 *
 * The linked Splunk topic “Instrument React Native Applications” is **Mobile RUM** (native apps),
 * not a browser bundle. For this Vite + React **web** app, use **Browser RUM**: manual injection
 * of the JavaScript agent with SPA2 enabled.
 *
 * @see https://help.splunk.com/en/appdynamics-saas/end-user-monitoring/26.4.0/end-user-monitoring/browser-monitoring/browser-real-user-monitoring/monitor-single-page-applications/spa2-monitoring/configure-spa2-monitoring
 * @see https://help.splunk.com/en/appdynamics-saas/end-user-monitoring/26.4.0/end-user-monitoring/browser-monitoring/browser-real-user-monitoring/inject-the-javascript-agent/manual-injection-of-the-javascript-agent
 */

declare global {
  interface Window {
    "adrum-start-time"?: number;
    "adrum-config"?: Record<string, unknown>;
  }
}

let appDynamicsInitStarted = false;

/**
 * Loads `adrum-latest.js` after setting `adrum-start-time` and `adrum-config`, per Splunk docs.
 * Enable with `VITE_APPDYNAMICS_ENABLED=true` and a non-empty `VITE_APPDYNAMICS_APP_KEY` from the
 * Controller “Get your application key” / Browser RUM instrumentation page (not the RN agent).
 */
function envTruthy(v: string | boolean | undefined): boolean {
  if (typeof v === "boolean") return v;
  return (v ?? "").trim().toLowerCase() === "true";
}

export function initAppDynamics(options?: { force?: boolean }): void {
  if (appDynamicsInitStarted) return;
  const enabled =
    options?.force === true || envTruthy(import.meta.env.VITE_APPDYNAMICS_ENABLED);
  const appKey = import.meta.env.VITE_APPDYNAMICS_APP_KEY?.trim();

  if (enabled && !appKey) {
    console.warn(
      "[AppDynamics Browser RUM] VITE_APPDYNAMICS_ENABLED is true but VITE_APPDYNAMICS_APP_KEY is empty, so the ADRUM script will not load. " +
        "For Vite, set the key in ecommerce-web/.env (dev) or pass build args from docker compose so it is baked into the production bundle.",
    );
  }
  if (!enabled || !appKey) {
    return;
  }
  appDynamicsInitStarted = true;

  const adrumExtUrlHttps =
    import.meta.env.VITE_APPDYNAMICS_ADRUM_EXT_URL_HTTPS ?? "https://cdn.appdynamics.com";
  const adrumExtUrlHttp =
    import.meta.env.VITE_APPDYNAMICS_ADRUM_EXT_URL_HTTP ?? "http://cdn.appdynamics.com";
  const beaconUrlHttps =
    import.meta.env.VITE_APPDYNAMICS_BEACON_URL_HTTPS ?? "https://col.eum-appdynamics.com";
  const beaconUrlHttp =
    import.meta.env.VITE_APPDYNAMICS_BEACON_URL_HTTP ?? "http://col.eum-appdynamics.com";
  const agentScriptUrl =
    import.meta.env.VITE_APPDYNAMICS_AGENT_SCRIPT_URL ??
    "https://cdn.appdynamics.com/adrum/adrum-latest.js";
  const spa2 = import.meta.env.VITE_APPDYNAMICS_SPA2 !== "false";
  const xdEnable = import.meta.env.VITE_APPDYNAMICS_XD_ENABLE === "true";

  window["adrum-start-time"] = new Date().getTime();
  const cfg = (window["adrum-config"] = window["adrum-config"] ?? {});
  cfg.appKey = appKey;
  cfg.adrumExtUrlHttp = adrumExtUrlHttp;
  cfg.adrumExtUrlHttps = adrumExtUrlHttps;
  cfg.beaconUrlHttp = beaconUrlHttp;
  cfg.beaconUrlHttps = beaconUrlHttps;
  cfg.enableCoreWebVitals = true;
  cfg.enableSpeedIndex = true;
  cfg.xd = { enable: xdEnable };
  cfg.spa = { spa2 };

  const script = document.createElement("script");
  script.src = agentScriptUrl;
  script.charset = "UTF-8";
  script.type = "text/javascript";
  // Dynamically inserted scripts default to async; keep false so config is applied before agent runs.
  script.async = false;
  document.head.appendChild(script);
}
