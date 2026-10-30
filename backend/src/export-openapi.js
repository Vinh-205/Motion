import { mkdirSync, writeFileSync } from "node:fs";
import { buildApp } from "./app.js";
// Schema generation only: no listening socket, no SMTP or production credentials.
const app = await buildApp(
  {
    databasePath: ":memory:",
    jwtSecret: "schema-only-not-a-production-key".repeat(2),
    otpSecret: "schema-only-otp".repeat(5),
    publicUrl: "https://motion-api.vihx.online",
  },
  {
    mailer: {
      sendMail: async () => {
        throw new Error("Schema export never sends email");
      },
    },
  },
);
await app.ready();
mkdirSync("openapi", { recursive: true });
writeFileSync(
  "openapi/motion.openapi.json",
  JSON.stringify(app.swagger(), null, 2) + "\n",
);
await app.close();
