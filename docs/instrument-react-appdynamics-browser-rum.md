# Instrument a React Web Application with Splunk AppDynamics Browser RUM

This guide explains how to add **Splunk AppDynamics Browser Real User Monitoring (Browser RUM)** to a **React web application**. React SPAs are monitored with the **JavaScript agent** and **SPA2** auto-instrumentation—not with the React Native mobile agent.

> **Scope:** This document covers React web apps (Vite, Create React App, etc.). For **React Native** mobile apps, use Mobile RUM instead. See [Instrument React Native Applications](https://help.splunk.com/en/appdynamics-saas/end-user-monitoring/26.5.0/end-user-monitoring/mobile-real-user-monitoring/instrument-react-native-applications).

## Requirements

| Requirement | Detail |
|---|---|
| AppDynamics SaaS account | Access to the Controller UI |
| Browser Application | Created under **End User Monitoring → Browser Monitoring** |
| EUM App Key | Generated in **Configuration → Configure JavaScript Agent** |
| JavaScript agent | SaaS: `adrum-latest.js` from the AppDynamics CDN (recommended) |
| SPA2 monitoring | `config.spa = { spa2: true }` — required for React auto-instrumentation |
| Agent version | JavaScript Agent >= 4.4.3; manual virtual-page naming API >= 4.5 |
| React app shell | Static `index.html` (Vite, CRA, or equivalent); agent loads **before** or at the start of the React entry module |

There is **no React-specific npm SDK** for web Browser RUM. Instrumentation is done via an HTML/JS snippet in `index.html` **or** programmatic injection from a Vite entry module, plus optional calls to the global `ADRUM` API.

### SPA2 requirements (React)

From the official SPA2 documentation:

- JavaScript Agent >= 4.4.3
- Controller / EUM Server >= 4.4.3 (on-premises deployments)
- Set `spa2: true` in the agent config **before** loading `adrum-latest.js`
- The default for `spa2` is `false`; you must explicitly enable it for React

SPA2 provides auto-instrumentation for React (and other SPA frameworks), detecting route transitions via `history.pushState`, `history.replaceState`, and hash changes without manual virtual-page API calls in most cases.

## How to instrument

### 1. Create and configure the Browser Application (Controller UI)

1. In the Controller UI, open or create a **Browser Application**.
2. Go to **Configuration → Configure JavaScript Agent**.
3. Configure the agent (app key, beacon URLs, hosting options).
4. Enable **SPA2** monitoring in the configuration.
5. Save and copy the generated HTML snippet.

Use the Controller-generated snippet as the source of truth for `appKey`, `beaconUrlHttp`, `beaconUrlHttps`, and CDN URLs. SaaS deployments typically use:

- CDN: `cdn.appdynamics.com`
- Beacon: `col.eum-appdynamics.com`

Regional SaaS controllers may use a regional collector (for example `pdx-col.eum-appdynamics.com`). Always copy beacon URLs from your Controller snippet rather than assuming the generic default.

### 2. Inject the JavaScript agent

Two valid approaches exist for Vite + React apps. Choose based on whether you need env-driven toggling or earliest possible page timing.

| | Path A: `index.html` snippet | Path B: Vite programmatic module |
|---|---|---|
| **Recommended by Splunk** | Yes | Valid alternative |
| **Earliest `adrum-start-time`** | Yes — inline in `<head>` | Slightly later — after Vite module parse |
| **Verify in page source** | Snippet visible in Elements | Script appended at runtime |
| **Env-based enable/disable** | Requires build plugin or separate HTML | Native `import.meta.env` + `.env` files |
| **Secrets in source** | Avoid — use build-time substitution | Keys stay in `.env` (not committed) |

#### Path A — Static snippet in `index.html` (Splunk recommended)

Manual injection is the primary path for React SPAs served as static assets. Place the configuration block and `adrum-latest.js` at the **top of `<head>`**, **before** your React entry script.

**Vite** (`index.html` at project root):

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>My React App</title>

    <!-- AppDynamics Browser RUM — load before React -->
    <script charset="UTF-8">
      window['adrum-start-time'] = new Date().getTime();
      (function (config) {
        config.appKey = '<EUM_APP_KEY>';
        config.adrumExtUrlHttp = 'http://cdn.appdynamics.com';
        config.adrumExtUrlHttps = 'https://cdn.appdynamics.com';
        config.beaconUrlHttp = 'http://col.eum-appdynamics.com';
        config.beaconUrlHttps = 'https://col.eum-appdynamics.com';
        config.xd = { enable: false };
        config.spa = { spa2: true };
      })(window['adrum-config'] || (window['adrum-config'] = {}));
    </script>
    <script
      src="//cdn.appdynamics.com/adrum/adrum-latest.js"
      type="text/javascript"
      charset="UTF-8"
    ></script>

    <!-- React entry follows -->
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

**Create React App** (`public/index.html`):

Use the same snippet in `<head>`, before `%PUBLIC_URL%` scripts or the root div. Replace `<EUM_APP_KEY>` with the key from the Controller, or inject it at build time via `REACT_APP_APPD_APP_KEY` using a small build-time replacement step.

**Environment-specific app keys (Path A only):**

- **Vite:** Keep secrets out of source control. Paste the Controller snippet per environment, or substitute `%VITE_APPD_APP_KEY%` with a build plugin (for example `vite-plugin-html`)—`import.meta.env` is not available in static HTML.
- **CRA:** Use `process.env.REACT_APP_APPD_APP_KEY` only in JavaScript modules, not in raw `public/index.html`, unless you replace placeholders at build time.

**Injection rules (both paths):**

- Load `adrum-latest.js` **synchronously** on the first page view. Do not use the `async` attribute on the initial load; async loading can cause the agent to miss Ajax events, resources, and errors.
- Set all configuration, including `spa2: true`, **before** loading `adrum-latest.js`.
- Place the agent at the top of `<head>` (Path A) for accurate page timing. NavTiming-capable browsers can tolerate other placements, but top-of-head is recommended.
- For SaaS, prefer `adrum-latest.js` over a pinned version unless you have a specific compatibility requirement.

#### Path B — Vite programmatic injection (env-driven)

Use this pattern when you want to enable or disable Browser RUM via Vite environment variables without maintaining separate HTML templates. The agent still loads **before** React mounts, but `adrum-start-time` is set slightly later than an inline `<head>` snippet (after the Vite entry module is parsed).

For a complete end-to-end walkthrough of this pattern (all files, e-commerce routes, env setup), see [Instrument Browser RUM — Vite programmatic injection](instrument-react-appdynamics-browser-rum-vite-programmatic.md).

**Implementation notes:**

- `import.meta.env` is **not** available in raw `index.html`; the programmatic path is how Vite apps typically wire env-based toggles.
- Dynamically inserted `<script>` elements default to `async`; set `script.async = false` so config is applied before the agent runs.
- Use an idempotent guard (`appDynamicsInitStarted`) to prevent double initialization during Vite HMR.
- Set `enableCoreWebVitals: true` when your agent version supports Core Web Vitals reporting.

**`src/appdynamics/initAppDynamics.ts`**

```typescript
/**
 * Splunk AppDynamics — Browser Real User Monitoring (JavaScript agent) for a React SPA.
 *
 * For Vite + React **web** apps, use **Browser RUM**: manual injection of the JavaScript
 * agent with SPA2 enabled — not the React Native mobile agent.
 */

declare global {
  interface Window {
    "adrum-start-time"?: number;
    "adrum-config"?: Record<string, unknown>;
  }
}

let appDynamicsInitStarted = false;

function envTruthy(v: string | boolean | undefined): boolean {
  if (typeof v === "boolean") return v;
  return (v ?? "").trim().toLowerCase() === "true";
}

/**
 * Loads `adrum-latest.js` after setting `adrum-start-time` and `adrum-config`.
 * Enable with `VITE_APPDYNAMICS_ENABLED=true` and a non-empty `VITE_APPDYNAMICS_APP_KEY`
 * from the Controller Browser RUM instrumentation page.
 */
export function initAppDynamics(): void {
  if (appDynamicsInitStarted) return;
  const enabled = envTruthy(import.meta.env.VITE_APPDYNAMICS_ENABLED);
  const appKey = import.meta.env.VITE_APPDYNAMICS_APP_KEY?.trim();

  if (enabled && !appKey) {
    console.warn(
      "[AppDynamics Browser RUM] VITE_APPDYNAMICS_ENABLED is true but VITE_APPDYNAMICS_APP_KEY is empty, so the ADRUM script will not load. " +
        "Set the key in .env or .env.local and restart the dev server.",
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
  cfg.xd = { enable: xdEnable };
  cfg.spa = { spa2 };

  const script = document.createElement("script");
  script.src = agentScriptUrl;
  script.charset = "UTF-8";
  script.type = "text/javascript";
  script.async = false;
  document.head.appendChild(script);
}
```

**`src/main.tsx`** — call `initAppDynamics()` before `createRoot()`:

```tsx
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import { initAppDynamics } from "@/appdynamics/initAppDynamics";
import { App } from "@/App";
import "@/index.css";

initAppDynamics();

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </StrictMode>,
);
```

**`src/vite-env.d.ts`** — TypeScript types for env vars:

```typescript
/// <reference types="vite/client" />

interface ImportMetaEnv {
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
```

**`.env.example`** — copy to `.env` or `.env.local`; do not commit real keys:

```bash
# User Experience > Browser RUM > your app > "Get your application key" / manual injection snippet.
# Do NOT commit real keys.

# --- Browser RUM (JavaScript agent) — NOT the React Native mobile agent ---
VITE_APPDYNAMICS_ENABLED=false
VITE_APPDYNAMICS_APP_KEY=

# Override if your Controller snippet shows different hosts (SaaS region / on-prem).
# VITE_APPDYNAMICS_ADRUM_EXT_URL_HTTPS=https://cdn.appdynamics.com
# VITE_APPDYNAMICS_ADRUM_EXT_URL_HTTP=http://cdn.appdynamics.com
# VITE_APPDYNAMICS_BEACON_URL_HTTPS=https://col.eum-appdynamics.com
# VITE_APPDYNAMICS_BEACON_URL_HTTP=http://col.eum-appdynamics.com
# Regional example (copy from Controller snippet):
# VITE_APPDYNAMICS_BEACON_URL_HTTPS=https://pdx-col.eum-appdynamics.com
# VITE_APPDYNAMICS_AGENT_SCRIPT_URL=https://cdn.appdynamics.com/adrum/adrum-latest.js

# SPA2 virtual page timing for this React SPA (Splunk default recommendation: true).
# VITE_APPDYNAMICS_SPA2=true
# VITE_APPDYNAMICS_XD_ENABLE=false
```

To enable RUM locally with Path B:

```bash
cp .env.example .env.local
# Set VITE_APPDYNAMICS_ENABLED=true and VITE_APPDYNAMICS_APP_KEY=<EUM_APP_KEY>
npm run dev   # restart after changing env files
```

#### Environment variables (Vite, Path B)

| Variable | Default in code | Purpose |
|---|---|---|
| `VITE_APPDYNAMICS_ENABLED` | — | Master switch (`"true"` to load agent) |
| `VITE_APPDYNAMICS_APP_KEY` | — | EUM browser app key (required when enabled) |
| `VITE_APPDYNAMICS_BEACON_URL_HTTPS` | `https://col.eum-appdynamics.com` | Beacon collector (HTTPS) |
| `VITE_APPDYNAMICS_BEACON_URL_HTTP` | `http://col.eum-appdynamics.com` | Beacon collector (HTTP fallback) |
| `VITE_APPDYNAMICS_ADRUM_EXT_URL_HTTPS` | `https://cdn.appdynamics.com` | Agent extension CDN (HTTPS) |
| `VITE_APPDYNAMICS_ADRUM_EXT_URL_HTTP` | `http://cdn.appdynamics.com` | Agent extension CDN (HTTP) |
| `VITE_APPDYNAMICS_AGENT_SCRIPT_URL` | `https://cdn.appdynamics.com/adrum/adrum-latest.js` | Agent script URL; pin version only if required |
| `VITE_APPDYNAMICS_SPA2` | enabled unless `"false"` | SPA2 auto virtual pages |
| `VITE_APPDYNAMICS_XD_ENABLE` | `false` unless `"true"` | Cross-domain sessions |

**Regional beacon:** Override `VITE_APPDYNAMICS_BEACON_URL_HTTPS` (and HTTP if needed) to match your Controller snippet—for example `https://pdx-col.eum-appdynamics.com` for PDX SaaS. Do not rely on generic defaults if the snippet shows a regional host.

**Security:** Never hardcode app keys in source. Keep real values in `.env.local` (gitignored) or your CI/CD secret store. Vite inlines `VITE_*` values at build time into the static bundle.

**Browser RUM vs JVM APM:** The EUM browser app key (`VITE_APPDYNAMICS_APP_KEY`) is separate from JVM APM credentials (`APPDYNAMICS_CONTROLLER_*`, access keys, tier names). Both may live in the same deployment env file but serve different agents.

### 3. SPA routing and virtual pages

#### Minimal path — SPA2 auto-instrumentation (recommended starting point)

With `config.spa = { spa2: true }`, the JavaScript agent auto-detects client-side navigations from React Router (via `history.pushState` / `replaceState`). A typical React Router v6 setup needs no extra RUM code:

```tsx
// src/App.tsx — routes only; SPA2 tracks /, /cart, /payment automatically
import { Navigate, Route, Routes } from "react-router-dom";

export function App() {
  return (
    <Routes>
      <Route index element={<HomePage />} />
      <Route path="cart" element={<CartPage />} />
      <Route path="payment" element={<PaymentPage />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
```

Mount `<BrowserRouter>` in `main.tsx` (see Path B sample above). Custom virtual page names are **optional** when SPA2 is enabled.

#### Optional enhancement — custom virtual page names

For clearer Controller dashboards, set virtual page names that match your routes:

```tsx
// src/appd/AppDynamicsRouteTracker.tsx
import { useEffect } from "react";
import { useLocation } from "react-router-dom";

declare global {
  interface Window {
    ADRUM?: {
      setVirtualPageName?: (name: string) => void;
      command?: (cmd: string, name: string) => void;
    };
  }
}

export function AppDynamicsRouteTracker() {
  const { pathname } = useLocation();

  useEffect(() => {
    const pageName = pathname || "/";
    window.ADRUM?.command?.("setVirtualPageName", pageName);
  }, [pathname]);

  return null;
}
```

Mount inside `<BrowserRouter>`:

```tsx
import { BrowserRouter } from "react-router-dom";
import { AppDynamicsRouteTracker } from "./appd/AppDynamicsRouteTracker";

export function App() {
  return (
    <BrowserRouter>
      <AppDynamicsRouteTracker />
      {/* routes */}
    </BrowserRouter>
  );
}
```

Requirements for custom virtual page names:

- SPA2 must be enabled (`config.spa = { spa2: true }`).
- Names must be 760 or fewer alphanumeric characters.
- Call `ADRUM.command("setVirtualPageName", ...)` or `ADRUM.setVirtualPageName(...)` after navigations the agent can track (for example, after `history.pushState`).

For manual virtual-page boundaries (rare with SPA2 + React Router), use `ADRUM.markVirtualPageBegin()` and `ADRUM.markVirtualPageEnd()` as documented in the JavaScript Agent API.

### 4. Disable monitoring in local or dev builds

Two patterns depending on injection path:

**Path A — `adrum-disable` in `index.html`**

Keep the snippet in place but stop sending data locally. Set `adrum-disable` **before** the agent config and `adrum-latest.js`:

```html
<head>
  <script type="text/javascript" charset="UTF-8">
    if (location.hostname === "localhost" || location.hostname === "127.0.0.1") {
      window["adrum-disable"] = true;
    }
  </script>

  <script charset="UTF-8">
    window["adrum-start-time"] = new Date().getTime();
    (function (config) {
      config.appKey = "<EUM_APP_KEY>";
      /* ... remaining config ... */
      config.spa = { spa2: true };
    })(window["adrum-config"] || (window["adrum-config"] = {}));
  </script>
  <script
    src="//cdn.appdynamics.com/adrum/adrum-latest.js"
    type="text/javascript"
    charset="UTF-8"
  ></script>
</head>
```

Remove the disable flag (or the conditional) to re-enable monitoring. Existing historical data in the Controller is preserved.

**Path B — env toggle (recommended for programmatic injection)**

Leave `VITE_APPDYNAMICS_ENABLED=false` in `.env.example` (default off). The agent script is not loaded at all in dev unless you explicitly set `VITE_APPDYNAMICS_ENABLED=true` and provide `VITE_APPDYNAMICS_APP_KEY`. Restart the Vite dev server after changing env files.

### 5. Verify instrumentation

After deploying or enabling locally, confirm monitoring is active:

1. **Path A — page source / DevTools → Elements:** Verify `adrum-config` and `adrum-latest.js` are present in `<head>`.
2. **Path B — DevTools → Elements / Network:** Confirm `adrum-latest.js` was appended to `<head>` and beacon requests are sent.
3. **DevTools → Network:** Look for beacon requests to your configured collector (for example `col.eum-appdynamics.com` or a regional host such as `pdx-col.eum-appdynamics.com`).
4. **DevTools → Console:** If using Path B with `VITE_APPDYNAMICS_ENABLED=true` but an empty app key, expect a `[AppDynamics Browser RUM]` warning and no agent load.
5. **Controller → Browser Application dashboard:** Allow a few minutes after first traffic for the page to be discovered and metrics to appear.
6. **Navigate between routes:** Confirm virtual pages appear in Browser RUM views when using React Router with SPA2 enabled.

**If no data appears, check:**

- Snippet not disabled (`adrum-disable` or `VITE_APPDYNAMICS_ENABLED=false`)
- App key matches the Browser Application in Controller (not the React Native or JVM agent key)
- Beacon URL matches your Controller snippet (wrong region is a common misconfiguration)
- Ad blockers or corporate proxies are not blocking beacon requests to `*.eum-appdynamics.com`
- For Path B: env vars were set before `npm run build` (Vite inlines them at compile time)

Review the troubleshooting guide linked in Sources for additional steps.

## Best practices

1. **Use SPA2 for React.** SPA2 auto-instruments React route transitions. SPA1 (AngularJS 1 only) is not suitable for React.
2. **Load the agent synchronously** on the first page view to avoid gaps in Ajax, resource, and error reporting.
3. **Place the agent before React.** Path A: `adrum-config` and `adrum-latest.js` in `<head>` before the application bundle. Path B: call `initAppDynamics()` before `createRoot()`.
4. **Choose the injection path deliberately.** Use inline `index.html` (Path A) when earliest paint timing matters; use programmatic injection (Path B) when env toggling and keeping keys out of HTML are priorities.
5. **Prefer Controller snippet values** for beacon and CDN URLs—regional collectors differ from generic SaaS defaults.
6. **Enable Core Web Vitals** with `enableCoreWebVitals: true` when supported by your agent version (shown in Path B sample).
7. **Do not disable Fetch monitoring for React.** Avoid `config.fetch = false`; that setting applies to Angular-specific scenarios. Fetch API calls are monitored by default for non-Angular SPAs.
8. **Use meaningful virtual page names** when using the optional route tracker. Align names with routes or features (`/checkout`, `/settings`) rather than opaque hash fragments that may contain sensitive data.
9. **Hide sensitive query strings** when URLs contain tokens or PII. Configure query-string filtering in the JavaScript agent settings.
10. **Use separate Browser Applications per environment** (development, staging, production) with distinct EUM app keys.
11. **Disable locally** with `adrum-disable` (Path A) or `VITE_APPDYNAMICS_ENABLED=false` (Path B) instead of maintaining separate templates without the agent.
12. **Plan for Content-Security-Policy (CSP).** If CSP blocks inline scripts or the AppDynamics CDN, follow the CSP guidance to allow required script sources and nonces for `adrum-ext.js`.
13. **Do not use this guide for React Native.** Mobile React Native apps require the separate React Native EUM agent, not the browser JavaScript snippet.

## Sources

Each URL was verified with HTTP GET on 2026-06-10. Only URLs returning **HTTP 200** are listed; all others are marked **No provided**.

| Topic | Source |
|---|---|
| Browser Monitoring overview | https://help.splunk.com/en/appdynamics-saas/end-user-monitoring/26.5.0/end-user-monitoring/browser-monitoring |
| Configure the JavaScript Agent | https://help.splunk.com/en/appdynamics-saas/end-user-monitoring/26.5.0/end-user-monitoring/browser-monitoring/browser-real-user-monitoring/configure-the-javascript-agent |
| Inject the JavaScript Agent | https://help.splunk.com/en/appdynamics-saas/end-user-monitoring/26.5.0/end-user-monitoring/browser-monitoring/browser-real-user-monitoring/inject-the-javascript-agent |
| Manual Injection of the JavaScript Agent | https://help.splunk.com/en/appdynamics-saas/end-user-monitoring/26.5.0/end-user-monitoring/browser-monitoring/browser-real-user-monitoring/inject-the-javascript-agent/manual-injection-of-the-javascript-agent |
| Monitor Single-Page Applications | https://help.splunk.com/en/appdynamics-saas/end-user-monitoring/26.5.0/end-user-monitoring/browser-monitoring/browser-real-user-monitoring/monitor-single-page-applications |
| SPA2 Monitoring | https://help.splunk.com/en/appdynamics-saas/end-user-monitoring/26.5.0/end-user-monitoring/browser-monitoring/browser-real-user-monitoring/monitor-single-page-applications/spa2-monitoring |
| Configure SPA2 Monitoring | https://help.splunk.com/en/appdynamics-saas/end-user-monitoring/26.5.0/end-user-monitoring/browser-monitoring/browser-real-user-monitoring/monitor-single-page-applications/spa2-monitoring/configure-spa2-monitoring |
| Set Custom Virtual Page Names | https://help.splunk.com/en/appdynamics-saas/end-user-monitoring/26.5.0/end-user-monitoring/browser-monitoring/browser-real-user-monitoring/configure-the-javascript-agent/set-custom-virtual-page-names |
| Disable Browser Monitoring Programmatically | https://help.splunk.com/en/appdynamics-saas/end-user-monitoring/26.5.0/end-user-monitoring/browser-monitoring/browser-real-user-monitoring/configure-the-javascript-agent/disable-browser-monitoring-programmatically |
| Enable the Content Security Policy (CSP) | https://help.splunk.com/en/appdynamics-saas/end-user-monitoring/26.5.0/end-user-monitoring/browser-monitoring/browser-real-user-monitoring/enable-the-content-security-policy-csp |
| Hide URL Query Strings | https://help.splunk.com/en/appdynamics-saas/end-user-monitoring/26.5.0/end-user-monitoring/browser-monitoring/browser-real-user-monitoring/configure-the-javascript-agent/hide-all-or-parts-of-the-url-query-string |
| Troubleshoot Browser RUM | https://help.splunk.com/en/appdynamics-saas/end-user-monitoring/26.5.0/end-user-monitoring/browser-monitoring/browser-real-user-monitoring/troubleshoot-browser-rum |
| Instrument React Native Applications (mobile — not web) | https://help.splunk.com/en/appdynamics-saas/end-user-monitoring/26.5.0/end-user-monitoring/mobile-real-user-monitoring/instrument-react-native-applications |
| CSP under Configure JavaScript Agent (nested path) | No provided |
