import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { resolve } from "node:path";

const viteCacheDir = process.env.LOCALAPPDATA
  ? resolve(process.env.LOCALAPPDATA, "SauverNdeko", "vite-cache")
  : resolve(".vite-cache");

export default defineConfig({
  plugins: [react()],
  cacheDir: viteCacheDir,
  server: {
    port: 5173,
    proxy: {
      "/api": "http://localhost:5000",
      "/SauverNdeko": "http://localhost:5000",
      "/health": "http://localhost:5000",
    },
  },
});
