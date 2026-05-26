import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import path from "node:path";

// Bookwall client is mounted under /ui in production, both dev and prod
// use the same base so relative paths in routes stay consistent.
export default defineConfig({
  base: "/ui/",
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  server: {
    port: 5173,
    proxy: {
      "/api": "http://localhost:3000",
      "/opds": "http://localhost:3000",
      "/rails": "http://localhost:3000",
      "/up": "http://localhost:3000",
    },
  },
});
