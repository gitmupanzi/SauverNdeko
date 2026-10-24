import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { resolve } from "node:path";

const viteCacheDir = process.env.LOCALAPPDATA
  ? resolve(process.env.LOCALAPPDATA, "SauverNdeko", "vite-cache")
  : resolve(".vite-cache");

const backendTarget = process.env.SAUVERNDEKO_BACKEND_URL || "http://127.0.0.1:5000";
const localAllowedHosts = (process.env.SAUVERNDEKO_LOCAL_ALLOWED_HOSTS || "")
  .split(",").map((host) => host.trim()).filter(Boolean);

export default defineConfig({
  plugins: [react()],
  cacheDir: viteCacheDir,
  server: {
    port: 5174,
    strictPort: true,
    allowedHosts: localAllowedHosts,
    proxy: {
      "/api": { target: backendTarget, changeOrigin: true },
      "/SauverNdeko": { target: backendTarget, changeOrigin: true },
      "/health": { target: backendTarget, changeOrigin: true },
    },
  },
});
