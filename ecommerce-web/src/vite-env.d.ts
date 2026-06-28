/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_BASE_URL?: string;
  /** Set to `"true"` to load the Browser RUM JavaScript agent. */
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
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
