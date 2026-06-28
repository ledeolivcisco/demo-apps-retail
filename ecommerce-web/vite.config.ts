import path from "node:path";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

/**
 * Dev proxy routes each backend path to the correct Spring Boot port so the SPA
 * stays same-origin and avoids browser CORS (backends do not send CORS headers).
 */
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "src"),
    },
  },
  server: {
    port: 5173,
    proxy: {
      "/productsearch": {
        target: "http://127.0.0.1:8081",
        changeOrigin: true,
      },
      "/getcart": {
        target: "http://127.0.0.1:8082",
        changeOrigin: true,
      },
      "/addproduct": {
        target: "http://127.0.0.1:8082",
        changeOrigin: true,
      },
      "/clearcart": {
        target: "http://127.0.0.1:8082",
        changeOrigin: true,
      },
      "/checkout": {
        target: "http://127.0.0.1:8082",
        changeOrigin: true,
      },
      "/pay": {
        target: "http://127.0.0.1:8083",
        changeOrigin: true,
      },
    },
  },
});
