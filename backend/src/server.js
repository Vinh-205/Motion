import { buildApp } from "./app.js";
import { configFromEnv } from "./security.js";

const app = await buildApp(configFromEnv(), { logger: true });
const stop = async () => {
  await app.close();
  process.exit(0);
};
process.on("SIGTERM", stop);
process.on("SIGINT", stop);
await app.listen({
  host: process.env.HOST || "0.0.0.0",
  port: Number(process.env.PORT || 3000),
});
