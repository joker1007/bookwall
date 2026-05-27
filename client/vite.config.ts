import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import path from "node:path";

// Bookwall client is mounted under /ui in production, both dev and prod
// use the same base so relative paths in routes stay consistent.
const apiTarget = process.env.BOOKWALL_API_TARGET ?? "http://localhost:3000";
const devPort = process.env.BOOKWALL_VITE_PORT
  ? Number(process.env.BOOKWALL_VITE_PORT)
  : 5173;

export default defineConfig({
  base: "/ui/",
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  server: {
    host: true,
    port: devPort,
    strictPort: true,
    proxy: {
      "/api": { target: apiTarget, changeOrigin: true },
      "/opds": { target: apiTarget, changeOrigin: true },
      "/rails": { target: apiTarget, changeOrigin: true },
      "/up": { target: apiTarget, changeOrigin: true },
    },
  },
});
