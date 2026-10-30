import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash, randomBytes, randomUUID } from "node:crypto";
import { buildApp } from "../src/app.js";
import { hashPassword } from "../src/security.js";
import { googleProvider } from "../src/google-oauth.js";
import { postgresFixture } from "./postgres-fixture.js";

const digest = (value) =>
  createHash("sha256").update(value).digest("base64url");
async function fixture(t, enabled = true) {
  const requests = new Map();
  let profile = {
    sub: "google-stable-subject",
    email: "owner@example.org",
    hd: "example.org",
    email_verified: true,
    name: "Google Test",
    role: "admin",
  };
  const provider = {
    authorizationUrl(value) {
      requests.set(value.state, value);
      const u = new URL("https://accounts.google.com/o/oauth2/v2/auth");
      u.search = new URLSearchParams({ state: value.state }).toString();
      return u.href;
    },
    async exchange(code, verifier) {
      const request = requests.get(code);
      if (!request) throw new Error("Invalid code");
      assert.equal(digest(verifier), request.codeChallenge);
      return { nonce: request.nonce, ...profile };
    },
  };
  const app = await buildApp(
    {
      databasePath: ":memory:",
      jwtSecret: "j".repeat(64),
      otpSecret: "o".repeat(64),
      publicUrl: "https://motion-api.vihx.online",
      ...(enabled
        ? { googleClientId: "test-client", googleClientSecret: "test-secret" }
        : {}),
    },
    {
      mailer: {
        sendMail: async () => {
          throw new Error("OAuth must not send email OTP");
        },
      },
      googleProvider: provider,
      store:
        process.env.MOTION_TEST_DATABASE === "postgres"
          ? await postgresFixture()
          : undefined,
    },
  );
  await app.ready();
  t.after(() => app.close());
  async function start({ token, linkAccount = false } = {}) {
    const verifier = randomBytes(32).toString("base64url");
    const response = await app.inject({
      method: "POST",
      url: "/auth/google/start",
      headers: token ? { authorization: `Bearer ${token}` } : {},
      payload: { codeChallenge: digest(verifier), linkAccount },
    });
    if (response.statusCode !== 200) return { response };
    const body = response.json(),
      state = new URL(body.authorizationUrl).searchParams.get("state");
    return { response, body, state, verifier };
  }
  async function callback(flow, params = {}) {
    const response = await app.inject({
      url:
        "/auth/google/callback?" +
        new URLSearchParams({ state: flow.state, code: flow.state, ...params }),
    });
    return {
      response,
      uri: response.headers.location
        ? new URL(response.headers.location)
        : null,
    };
  }
  const exchange = (flow, uri, overrides = {}) =>
    app.inject({
      method: "POST",
      url: "/auth/google/exchange",
      payload: {
        flowId: flow.body.flowId,
        ticket: uri.searchParams.get("ticket"),
        codeVerifier: flow.verifier,
        ...overrides,
      },
    });
  async function seed(role = "member", email = "owner@example.org") {
    const id = randomUUID(),
      sid = randomUUID();
    await app.store.run(
      "INSERT INTO users(id,email,name,password,role,verified,created_at) VALUES(?,?,?,?,?,1,?)",
      id,
      email,
      "Existing",
      await hashPassword("test-password-only"),
      role,
      Date.now(),
    );
    await app.store.run(
      "INSERT INTO sessions(id,user_id,expires_at) VALUES(?,?,?)",
      sid,
      id,
      Date.now() + 100000,
    );
    return { id, token: app.jwt.sign({ sub: id, sid }) };
  }
  return {
    app,
    start,
    callback,
    exchange,
    seed,
    setProfile: (value) => {
      profile = { ...profile, ...value };
    },
  };
}

test("Google provider builds official OIDC authorization code URL without exposing a secret", () => {
  const provider = googleProvider({
    googleClientId: "test-client",
    googleClientSecret: "must-stay-server-side",
    publicUrl: "https://motion-api.vihx.online",
  });
  const url = new URL(
    provider.authorizationUrl({
      state: "state",
      nonce: "nonce",
      codeChallenge: "challenge",
    }),
  );
  assert.equal(url.origin, "https://accounts.google.com");
  assert.equal(url.searchParams.get("response_type"), "code");
  assert.equal(
    url.searchParams.get("redirect_uri"),
    "https://motion-api.vihx.online/auth/google/callback",
  );
  assert.equal(url.searchParams.get("code_challenge_method"), "S256");
  assert.equal(url.searchParams.get("nonce"), "nonce");
  assert.ok(url.searchParams.get("scope").includes("openid"));
  assert.equal(url.href.includes("must-stay-server-side"), false);
});
test("new Google account becomes member, callback has no JWT, ticket is PKCE-bound and single use", async (t) => {
  const f = await fixture(t),
    flow = await f.start(),
    { response, uri } = await f.callback(flow);
  assert.equal(response.statusCode, 302);
  assert.equal(uri.protocol, "com.vihx.motion:");
  assert.equal(uri.searchParams.has("accessToken"), false);
  assert.equal(response.headers["cache-control"], "no-store");
  const wrong = await f.exchange(flow, uri, {
    codeVerifier: randomBytes(32).toString("base64url"),
  });
  assert.equal(wrong.statusCode, 400);
  const login = await f.exchange(flow, uri);
  assert.equal(login.statusCode, 200);
  assert.equal(login.json().user.role, "member");
  assert.ok(login.json().accessToken);
  assert.equal((await f.exchange(flow, uri)).statusCode, 400);
  assert.equal((await f.callback(flow)).response.statusCode, 400);
  const saved = await f.app.store.one(
    "SELECT * FROM google_oauth_flows WHERE id=?",
    flow.body.flowId,
  );
  assert.equal(saved.google_verifier, "");
  assert.notEqual(saved.ticket_digest, uri.searchParams.get("ticket"));
});
test("unconfigured Google is disabled without affecting password endpoints", async (t) => {
  const f = await fixture(t, false);
  assert.equal((await f.start()).response.statusCode, 503);
  assert.equal((await f.app.inject("/health")).statusCode, 200);
});
test("invalid state, expired state, cancelled consent and invalid nonce never create users", async (t) => {
  const f = await fixture(t);
  assert.equal(
    (await f.app.inject("/auth/google/callback?state=unknown&code=x"))
      .statusCode,
    400,
  );
  const expired = await f.start();
  await f.app.store.run(
    "UPDATE google_oauth_flows SET expires_at=? WHERE id=?",
    Date.now() - 1,
    expired.body.flowId,
  );
  assert.equal((await f.callback(expired)).response.statusCode, 400);
  const cancelled = await f.start();
  assert.equal(
    (
      await f.callback(cancelled, { error: "access_denied" })
    ).uri.searchParams.get("error"),
    "cancelled",
  );
  f.setProfile({ nonce: "wrong-nonce" });
  const invalid = await f.start();
  assert.equal(
    (await f.callback(invalid)).uri.searchParams.get("error"),
    "invalid_identity",
  );
  assert.equal((await f.app.store.one("SELECT COUNT(*) AS n FROM users")).n, 0);
});
test("unverified Google email is rejected", async (t) => {
  const f = await fixture(t);
  f.setProfile({ email_verified: false });
  const flow = await f.start();
  assert.equal(
    (await f.callback(flow)).uri.searchParams.get("error"),
    "invalid_identity",
  );
});

test("non-Gmail external mailboxes require Motion OTP registration before linking", async (t) => {
  const f = await fixture(t);
  f.setProfile({ hd: undefined, email_verified: true });
  const flow = await f.start();
  assert.equal(
    (await f.callback(flow)).uri.searchParams.get("error"),
    "email_verification_required",
  );
  assert.equal((await f.app.store.one("SELECT COUNT(*) AS n FROM users")).n, 0);
});

test("Gmail can create a member without a Workspace hd claim", async (t) => {
  const f = await fixture(t);
  f.setProfile({ email: "motion-test-member@gmail.com", hd: undefined });
  const flow = await f.start(),
    result = await f.callback(flow);
  const session = await f.exchange(flow, result.uri);
  assert.equal(session.statusCode, 200);
  assert.equal(session.json().user.role, "member");
});
test("existing email never auto-links; authenticated explicit linking preserves admin role", async (t) => {
  const f = await fixture(t),
    admin = await f.seed("admin");
  const guest = await f.start();
  assert.equal(
    (await f.callback(guest)).uri.searchParams.get("error"),
    "account_exists",
  );
  assert.equal(
    (await f.app.store.one("SELECT COUNT(*) AS n FROM google_identities")).n,
    0,
  );
  assert.equal((await f.start({ linkAccount: true })).response.statusCode, 401);
  const linked = await f.start({ token: admin.token, linkAccount: true }),
    result = await f.callback(linked);
  assert.equal(
    (await f.exchange(linked, result.uri)).json().user.role,
    "admin",
  );
  const next = await f.start(),
    nextResult = await f.callback(next);
  assert.equal(
    (await f.exchange(next, nextResult.uri)).json().user.id,
    admin.id,
  );
});
test("linking a different mailbox is rejected and locked users cannot exchange an issued ticket", async (t) => {
  const f = await fixture(t),
    member = await f.seed("member", "different@example.org");
  const mismatch = await f.start({ token: member.token, linkAccount: true });
  assert.equal(
    (await f.callback(mismatch)).uri.searchParams.get("error"),
    "email_mismatch",
  );
  const flow = await f.start(),
    result = await f.callback(flow);
  await f.app.store.run(
    "UPDATE users SET active=0 WHERE email=?",
    "owner@example.org",
  );
  assert.equal((await f.exchange(flow, result.uri)).statusCode, 403);
});
test("expired tickets cannot produce a session and OAuth models are documented", async (t) => {
  const f = await fixture(t),
    flow = await f.start(),
    result = await f.callback(flow);
  await f.app.store.run(
    "UPDATE google_oauth_flows SET expires_at=? WHERE id=?",
    Date.now() - 1,
    flow.body.flowId,
  );
  assert.equal((await f.exchange(flow, result.uri)).statusCode, 400);
  const doc = f.app.swagger();
  assert.ok(doc.components.schemas.GoogleOAuthStartRequest);
  assert.ok(doc.components.schemas.GoogleOAuthExchangeRequest);
});

test("revoking or expiring the originating session prevents pending Google linking", async (t) => {
  const f = await fixture(t),
    member = await f.seed();
  const revoked = await f.start({ token: member.token, linkAccount: true });
  await f.app.store.run("DELETE FROM sessions WHERE user_id=?", member.id);
  assert.equal((await f.callback(revoked)).response.statusCode, 400);
  assert.equal(
    (await f.app.store.one("SELECT COUNT(*) AS n FROM google_identities")).n,
    0,
  );
  const sid = randomUUID();
  await f.app.store.run(
    "INSERT INTO sessions(id,user_id,expires_at) VALUES(?,?,?)",
    sid,
    member.id,
    Date.now() + 100000,
  );
  const token = f.app.jwt.sign({ sub: member.id, sid });
  const expired = await f.start({ token, linkAccount: true });
  await f.app.store.run(
    "UPDATE sessions SET expires_at=? WHERE id=?",
    Date.now() - 1,
    sid,
  );
  assert.equal(
    (await f.callback(expired)).uri.searchParams.get("error"),
    "authorization_expired",
  );
  assert.equal(
    (await f.app.store.one("SELECT COUNT(*) AS n FROM google_identities")).n,
    0,
  );
});
