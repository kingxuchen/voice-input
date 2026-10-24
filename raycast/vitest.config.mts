import { defineConfig } from "vitest/config";
import { resolve } from "node:path";

// @raycast/api 只在 Raycast 运行时解析（无 ESM 入口），单测一律走桩。
export default defineConfig({
  resolve: {
    alias: {
      "@raycast/api": resolve(__dirname, "src/test/raycast-api-stub.ts"),
    },
  },
  test: {
    include: ["src/**/*.test.ts"],
  },
});
