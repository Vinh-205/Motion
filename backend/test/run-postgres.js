import { spawnSync } from "node:child_process";
const result = spawnSync(
  process.execPath,
  ["--test", "test/api.test.js", "test/google-oauth.test.js"],
  {
    env: { ...process.env, MOTION_TEST_DATABASE: "postgres" },
    stdio: "inherit",
    windowsHide: true,
  },
);
process.exitCode = result.status ?? 1;
