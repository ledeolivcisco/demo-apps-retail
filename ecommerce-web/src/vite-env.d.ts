/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_BASE_URL?: string;
  /** Master RUM backend: `appdynamics` | `splunk` | `none`. Falls back to VITE_APPDYNAMICS_ENABLED when unset. */
  readonly VITE_OBSERVABILITY_BACKEND?: string;
  /** Set to `"true"` to load the Browser RUM JavaScript agent (legacy; prefer VITE_OBSERVABILITY_BACKEND). */
  readonly VITE_APPDYNAMICS_ENABLED?: string;
  /** EUM / Browser application key from the Controller (never commit real values). */
  readonly VITE_APPDYNAMICS_APP_KEY?: string;
  readonly VITE_APPDYNAMICS_ADRUM_EXT_URL_HTTPS?: string;
  readonly VITE_APPDYNAMICS_ADRUM_EXT_URL_HTTP?: string;
  readonly VITE_APPDYNAMICS_BEACON_URL_HTTPS?: string;
  readonly VITE_APPDYNAMICS_BEACON_URL_HTTP?: string;
  readonly VITE_APPDYNAMICS_AGENT_SCRIPT_URL?: string;
  /** Default enabled; set to `"false"` to disable SPA2 auto-instrumentation. */
  readonly VITE_APPDYNAMICS_SPA2?: string;
  /** Cross-domain session; default false per Splunk SPA2 sample. */
  readonly VITE_APPDYNAMICS_XD_ENABLE?: string;
  /** Splunk Observability Cloud realm (e.g. us1). Required when backend is splunk. */
  readonly VITE_SPLUNK_REALM?: string;
  /** RUM access token from Observability Cloud (never commit real values). */
  readonly VITE_SPLUNK_RUM_ACCESS_TOKEN?: string;
  readonly VITE_SPLUNK_APPLICATION_NAME?: string;
  readonly VITE_SPLUNK_DEPLOYMENT_ENVIRONMENT?: string;
  /** SPA route metrics; default enabled unless `"false"`. */
  readonly VITE_SPLUNK_SPA_METRICS?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
