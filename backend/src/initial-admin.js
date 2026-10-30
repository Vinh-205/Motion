import { randomUUID } from "node:crypto";
import { hashPassword } from "./security.js";

// Render Free has no shell / one-off jobs. Explicit private env variables allow
// the very first admin to be created before the HTTP listener opens.
export async function ensureInitialAdmin(store, env = process.env) {
  const email = env.BOOTSTRAP_ADMIN_EMAIL?.trim().toLowerCase();
  const password = env.BOOTSTRAP_ADMIN_PASSWORD;
  if (!email && !password) return false;
  const errors = [];
  if (!email) errors.push("BOOTSTRAP_ADMIN_EMAIL is missing or empty");
  else if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) || /["'<>]/.test(email)) {
    errors.push(
      "BOOTSTRAP_ADMIN_EMAIL must be a valid email address without quotes or a display name",
    );
  }
  if (!password) errors.push("BOOTSTRAP_ADMIN_PASSWORD is missing or empty");
  else {
    if (password.length < 14 || password.length > 128) {
      errors.push(
        `BOOTSTRAP_ADMIN_PASSWORD must contain 14-128 characters; received length=${password.length}`,
      );
    }
    if (/[\r\n]/.test(password))
      errors.push("BOOTSTRAP_ADMIN_PASSWORD must not contain line breaks");
  }
  if (errors.length)
    throw new Error(
      `Initial admin configuration invalid: ${errors.join("; ")}. Update Render Environment and redeploy.`,
    );
  const existing = await store.one(
    "SELECT role FROM users WHERE email=?",
    email,
  );
  if (existing) {
    if (existing.role !== "admin")
      throw new Error(
        "Bootstrap refuses to elevate an existing non-admin account",
      );
    return false; // Restarts never reset the password or recreate accounts.
  }
  if (
    (await store.one("SELECT COUNT(*) AS n FROM users WHERE role='admin'")).n >
    0
  )
    return false;
  const encoded = await hashPassword(password);
  await store.transaction(async () => {
    const admins = await store.one(
      "SELECT COUNT(*) AS n FROM users WHERE role='admin'",
    );
    if (admins.n > 0) return;
    await store.run(
      "INSERT INTO users(id,email,name,password,role,verified,created_at) VALUES(?,?,?,?,'admin',1,?)",
      randomUUID(),
      email,
      "Motion Admin",
      encoded,
      Date.now(),
    );
  });
  return true;
}
