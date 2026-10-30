import { test } from "node:test";
import assert from "node:assert/strict";
import { createMailer } from "../src/mailer.js";
import { ensureInitialAdmin } from "../src/initial-admin.js";
import { openStore } from "../src/store.js";
import { verifyPassword, configFromEnv } from "../src/security.js";

test("Resend sends OTP over HTTPS; provider errors are never treated as success", async () => {
  let request;
  const mailer = createMailer(
    { mailProvider: "resend", resendApiKey: "test-only" },
    async (url, options) => {
      request = { url, options };
      return { ok: true, json: async () => ({ id: "email-id" }) };
    },
  );
  const mail = {
    from: "Motion <no-reply@example.org>",
    to: "owner@example.org",
    subject: "OTP",
    text: "Test 123456",
  };
  assert.equal((await mailer.sendMail(mail)).messageId, "email-id");
  assert.equal(request.url, "https://api.resend.com/emails");
  assert.deepEqual(JSON.parse(request.options.body), {
    ...mail,
    to: [mail.to],
  });
  const failing = createMailer(
    { mailProvider: "resend", resendApiKey: "test-only" },
    async () => ({ ok: false, status: 429 }),
  );
  await assert.rejects(failing.sendMail(mail), /429/);
});
test("first admin bootstrap is idempotent and never resets a password", async (t) => {
  const store = openStore(":memory:");
  t.after(() => store.close());
  const env = {
    BOOTSTRAP_ADMIN_EMAIL: "admin@example.org",
    BOOTSTRAP_ADMIN_PASSWORD: "initial-test-password-123",
  };
  assert.equal(await ensureInitialAdmin(store, env), true);
  assert.equal(
    await ensureInitialAdmin(store, {
      ...env,
      BOOTSTRAP_ADMIN_PASSWORD: "changed-test-password-123",
    }),
    false,
  );
  const user = await store.one("SELECT * FROM users");
  assert.equal(user.role, "admin");
  assert.equal(
    await verifyPassword(env.BOOTSTRAP_ADMIN_PASSWORD, user.password),
    true,
  );
  assert.equal((await store.one("SELECT COUNT(*) AS n FROM users")).n, 1);
  await store.run("UPDATE users SET role='member'");
  await assert.rejects(ensureInitialAdmin(store, env), /refuses to elevate/);
});
test("Render rejects ephemeral SQLite and supports HTTPS mail configuration", () => {
  const saved = { ...process.env };
  try {
    Object.assign(process.env, {
      RENDER: "true",
      JWT_SECRET: "a".repeat(32),
      OTP_SECRET: "b".repeat(32),
      MAIL_PROVIDER: "resend",
      RESEND_API_KEY: "test-only",
      MAIL_FROM: "no-reply@example.org",
      RENDER_EXTERNAL_URL: "https://motion-example.onrender.com",
    });
    delete process.env.DATABASE_URL;
    delete process.env.PUBLIC_URL;
    assert.throws(() => configFromEnv(), /DATABASE_URL/);
    process.env.DATABASE_URL =
      "postgresql://test.invalid/example?sslmode=require";
    assert.equal(configFromEnv().mailProvider, "resend");
    assert.equal(configFromEnv().publicUrl, process.env.RENDER_EXTERNAL_URL);
  } finally {
    for (const key of Object.keys(process.env))
      if (!(key in saved)) delete process.env[key];
    Object.assign(process.env, saved);
  }
});

test("bootstrap diagnoses invalid configuration without logging credentials", async (t) => {
  const store = openStore(":memory:");
  t.after(() => store.close());
  const cases = [
    [{ BOOTSTRAP_ADMIN_EMAIL: "admin@example.org" }, /PASSWORD is missing/],
    [
      { BOOTSTRAP_ADMIN_PASSWORD: "synthetic-test-password" },
      /EMAIL is missing/,
    ],
    [
      {
        BOOTSTRAP_ADMIN_EMAIL: "not-an-email",
        BOOTSTRAP_ADMIN_PASSWORD: "synthetic-test-password",
      },
      /EMAIL must be a valid/,
    ],
    [
      {
        BOOTSTRAP_ADMIN_EMAIL: "admin@example.org",
        BOOTSTRAP_ADMIN_PASSWORD: "short1234",
      },
      /received length=9/,
    ],
    [
      {
        BOOTSTRAP_ADMIN_EMAIL: "admin@example.org",
        BOOTSTRAP_ADMIN_PASSWORD: "synthetic-test-password\n",
      },
      /line breaks/,
    ],
  ];
  for (const [env, pattern] of cases) {
    await assert.rejects(ensureInitialAdmin(store, env), (error) => {
      assert.match(error.message, pattern);
      if (env.BOOTSTRAP_ADMIN_PASSWORD)
        assert.equal(
          error.message.includes(env.BOOTSTRAP_ADMIN_PASSWORD),
          false,
        );
      if (env.BOOTSTRAP_ADMIN_EMAIL)
        assert.equal(error.message.includes(env.BOOTSTRAP_ADMIN_EMAIL), false);
      return true;
    });
  }
  assert.equal((await store.one("SELECT COUNT(*) AS n FROM users")).n, 0);
});
