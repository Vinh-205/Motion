import { randomUUID } from "node:crypto";
import { storeFromConfig } from "./store.js";
import { hashPassword } from "./security.js";

const email = process.env.ADMIN_EMAIL?.trim().toLowerCase();
const password = process.env.ADMIN_PASSWORD ?? "";
if (
  !email ||
  !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) ||
  password.length < 14 ||
  password.length > 128
) {
  throw new Error(
    "Set valid ADMIN_EMAIL and ADMIN_PASSWORD (14-128 characters) in private .env",
  );
}
const store = await storeFromConfig({
  databaseUrl: process.env.DATABASE_URL,
  databasePath: process.env.DATABASE_PATH || "./data/motion.sqlite",
});
try {
  if (await store.one("SELECT id FROM users WHERE email=?", email))
    throw new Error(
      "Account already exists; refusing to change its role or password",
    );
  const encoded = await hashPassword(password);
  await store.run(
    "INSERT INTO users(id,email,name,password,role,verified,created_at) VALUES(?,?,?,?,'admin',1,?)",
    randomUUID(),
    email,
    process.env.ADMIN_NAME || "Motion Admin",
    encoded,
    Date.now(),
  );
  console.log(
    "Admin created. Remove ADMIN_PASSWORD from .env. Login still requires Email OTP.",
  );
} finally {
  await store.close();
}
