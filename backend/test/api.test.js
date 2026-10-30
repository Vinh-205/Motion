import { test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { buildApp } from "../src/app.js";
import { hashPassword } from "../src/security.js";
import { postgresFixture } from "./postgres-fixture.js";

async function fixture(t) {
  const mails = [];
  const app = await buildApp(
    {
      databasePath: ":memory:",
      jwtSecret: "j".repeat(64),
      otpSecret: "o".repeat(64),
      publicUrl: "https://motion-api.vihx.online",
      mailFrom: "test@example.org",
    },
    {
      mailer: { sendMail: async (mail) => mails.push(mail) },
      store:
        process.env.MOTION_TEST_DATABASE === "postgres"
          ? await postgresFixture()
          : undefined,
    },
  );
  await app.ready();
  // Use isolated stores/mailboxes per test. No server socket or real email/SMS/call.
  t.after(() => app.close());
  const call = async (method, url, payload, token) => {
    const response = await app.inject({
      method,
      url,
      payload,
      headers: token ? { authorization: `Bearer ${token}` } : {},
    });
    return { status: response.statusCode, data: response.json() };
  };
  const pass = "test-only-password-123";
  async function seed(role = "member", name = randomUUID()) {
    const id = randomUUID(),
      address = `${name}@example.org`;
    await app.store.run(
      "INSERT INTO users(id,email,name,password,role,verified,created_at) VALUES(?,?,?,?,?,1,?)",
      id,
      address,
      name,
      await hashPassword(pass),
      role,
      Date.now(),
    );
    const sid = randomUUID();
    await app.store.run(
      "INSERT INTO sessions VALUES(?,?,?)",
      sid,
      id,
      Date.now() + 100000,
    );
    return { id, email: address, token: app.jwt.sign({ sub: id, sid }) };
  }
  const code = () => mails.at(-1).text.match(/\b\d{6}\b/)[0];
  return { app, call, seed, code, mails, pass };
}

test("email registration, verification and password + OTP login; OTP cannot be reused", async (t) => {
  const f = await fixture(t),
    email = "new@example.org";
  let r = await f.call("POST", "/auth/register", {
    email,
    name: "Vinh",
    password: f.pass,
  });
  assert.equal(r.status, 200);
  assert.equal(r.data.code, undefined);
  assert.equal(f.mails.length, 1);
  const verify = { challengeId: r.data.challengeId, code: f.code() };
  assert.equal(
    (await f.call("POST", "/auth/login", { email, password: f.pass })).status,
    401,
  );
  assert.equal(
    (await f.call("POST", "/auth/verify-email", verify)).status,
    200,
  );
  assert.equal(
    (await f.call("POST", "/auth/verify-email", verify)).status,
    400,
  );
  r = await f.call("POST", "/auth/login", { email, password: f.pass });
  assert.equal(r.status, 200);
  const login = { challengeId: r.data.challengeId, code: f.code() };
  r = await f.call("POST", "/auth/login/verify", login);
  assert.equal(r.status, 200);
  assert.equal(r.data.user.role, "member");
  assert.equal(
    (await f.call("GET", "/me", undefined, r.data.accessToken)).status,
    200,
  );
  assert.equal((await f.call("POST", "/auth/login/verify", login)).status, 400);
});
test("OTP expires, is purpose bound, caps attempts and resend cooldown", async (t) => {
  const f = await fixture(t),
    user = await f.seed();
  const r = await f.call("POST", "/auth/login", {
    email: user.email,
    password: f.pass,
  });
  const code = f.code();
  assert.equal(
    (
      await f.call("POST", "/auth/login", {
        email: user.email,
        password: f.pass,
      })
    ).status,
    429,
  );
  assert.equal(
    (
      await f.call("POST", "/auth/verify-email", {
        challengeId: r.data.challengeId,
        code,
      })
    ).status,
    400,
  );
  const wrong = code === "000000" ? "111111" : "000000";
  for (let i = 0; i < 5; i++)
    assert.equal(
      (
        await f.call("POST", "/auth/login/verify", {
          challengeId: r.data.challengeId,
          code: wrong,
        })
      ).status,
      400,
    );
  assert.equal(
    (
      await f.call("POST", "/auth/login/verify", {
        challengeId: r.data.challengeId,
        code,
      })
    ).status,
    400,
  );
  await f.app.store.run(
    "UPDATE challenges SET attempts=0,expires_at=? WHERE id=?",
    Date.now() - 1,
    r.data.challengeId,
  );
  assert.equal(
    (
      await f.call("POST", "/auth/login/verify", {
        challengeId: r.data.challengeId,
        code,
      })
    ).status,
    400,
  );
});
test("reset password and logout revoke server sessions", async (t) => {
  const f = await fixture(t),
    user = await f.seed();
  const r = await f.call("POST", "/auth/forgot-password", {
    email: user.email,
  });
  assert.equal(
    (
      await f.call("POST", "/auth/reset-password", {
        challengeId: r.data.challengeId,
        code: f.code(),
        password: "new-password-12345",
      })
    ).status,
    200,
  );
  assert.equal((await f.call("GET", "/me", undefined, user.token)).status, 401);
  assert.equal(
    (
      await f.call("POST", "/auth/login", {
        email: user.email,
        password: f.pass,
      })
    ).status,
    401,
  );
  assert.equal(
    (
      await f.call("POST", "/auth/login", {
        email: user.email,
        password: "new-password-12345",
      })
    ).status,
    200,
  );
  const another = await f.seed();
  assert.equal(
    (await f.call("POST", "/auth/logout", undefined, another.token)).status,
    200,
  );
  assert.equal(
    (await f.call("GET", "/me", undefined, another.token)).status,
    401,
  );
});
test("CRUD contact rejects cross-owner reads/writes, role injection and duplicate phone", async (t) => {
  const f = await fixture(t),
    a = await f.seed(),
    b = await f.seed();
  assert.equal(
    (
      await f.call("POST", "/auth/register", {
        email: "inject@example.org",
        name: "x",
        password: f.pass,
        role: "admin",
      })
    ).status,
    400,
  );
  assert.equal(
    (await f.call("PATCH", "/me", { name: "X", role: "admin" }, a.token))
      .status,
    400,
  );
  let r = await f.call(
    "POST",
    "/contacts",
    { name: "Emergency", phone: "+84 912 345 678" },
    a.token,
  );
  assert.equal(r.status, 200);
  const id = r.data.id;
  assert.equal(
    (
      await f.call(
        "POST",
        "/contacts",
        { name: "Duplicate", phone: "0912345678" },
        a.token,
      )
    ).status,
    409,
  );
  assert.equal(
    (await f.call("GET", `/contacts?ownerId=${a.id}`, undefined, b.token))
      .status,
    403,
  );
  for (const method of ["GET", "PATCH", "DELETE"])
    assert.equal(
      (
        await f.call(
          method,
          `/contacts/${id}`,
          method === "PATCH" ? { name: "stolen" } : undefined,
          b.token,
        )
      ).status,
      404,
    );
  assert.equal(
    (
      await f.call(
        "POST",
        "/contacts",
        { ownerId: a.id, name: "x", phone: "0987654321" },
        b.token,
      )
    ).status,
    403,
  );
  assert.equal(
    (await f.call("PATCH", `/contacts/${id}`, { name: "Updated" }, a.token))
      .data.name,
    "Updated",
  );
  assert.equal(
    (await f.call("GET", `/contacts/${id}`, undefined, a.token)).data.phone,
    "0912345678",
  );
  assert.equal(
    (await f.call("DELETE", `/contacts/${id}`, undefined, a.token)).status,
    200,
  );
  assert.equal(
    (await f.call("GET", `/contacts/${id}`, undefined, a.token)).status,
    404,
  );
});
test("admin CRUD users, assignment, staff access and last-admin protection", async (t) => {
  const f = await fixture(t),
    admin = await f.seed("admin"),
    staff = await f.seed("staff"),
    other = await f.seed("staff"),
    member = await f.seed();
  assert.equal(
    (
      await f.call(
        "POST",
        "/users",
        {
          email: "staff@example.org",
          name: "Staff",
          password: f.pass,
          role: "staff",
        },
        member.token,
      )
    ).status,
    403,
  );
  assert.equal(
    (
      await f.call(
        "POST",
        "/users",
        {
          email: "staff@example.org",
          name: "Staff",
          password: f.pass,
          role: "staff",
        },
        admin.token,
      )
    ).status,
    200,
  );
  assert.equal(
    (
      await f.call(
        "PATCH",
        `/users/${member.id}`,
        { assignedStaffId: staff.id },
        admin.token,
      )
    ).status,
    200,
  );
  const contact = await f.call(
    "POST",
    "/contacts",
    { ownerId: member.id, name: "x", phone: "0987654321" },
    staff.token,
  );
  assert.equal(contact.status, 200);
  assert.equal(
    (
      await f.call(
        "GET",
        `/contacts/${contact.data.id}`,
        undefined,
        other.token,
      )
    ).status,
    404,
  );
  assert.equal(
    (await f.call("GET", "/users", undefined, staff.token)).data.items.length,
    2,
  );
  assert.equal(
    (
      await f.call(
        "PATCH",
        `/users/${staff.id}`,
        { active: false },
        admin.token,
      )
    ).status,
    200,
  );
  assert.equal(
    (await f.call("GET", "/me", undefined, staff.token)).status,
    401,
  );
  assert.equal(
    (await f.call("DELETE", `/users/${admin.id}`, undefined, admin.token))
      .status,
    409,
  );
  assert.equal(
    (
      await f.call(
        "PATCH",
        `/users/${admin.id}`,
        { role: "member" },
        admin.token,
      )
    ).status,
    409,
  );
  assert.equal(
    (await f.call("DELETE", `/users/${member.id}`, undefined, admin.token))
      .status,
    200,
  );
  assert.equal(
    await f.app.store.one(
      "SELECT id FROM contacts WHERE id=?",
      contact.data.id,
    ),
    undefined,
  );
});
test("safety circle full CRUD, overdue and ownership enforcement", async (t) => {
  const f = await fixture(t),
    a = await f.seed(),
    b = await f.seed();
  const created = await f.call(
    "POST",
    "/checkins",
    { title: "Check after walk", dueAt: Date.now() + 60000 },
    a.token,
  );
  assert.equal(created.status, 200);
  const id = created.data.id;
  assert.equal(
    (await f.call("GET", `/checkins/${id}`, undefined, b.token)).status,
    404,
  );
  assert.equal(
    (await f.call("PATCH", `/checkins/${id}`, { status: "safe" }, b.token))
      .status,
    404,
  );
  assert.equal(
    (
      await f.call(
        "PATCH",
        `/checkins/${id}`,
        { status: "needs_help", note: "Please contact me" },
        a.token,
      )
    ).data.status,
    "needs_help",
  );
  assert.equal(
    (await f.call("PATCH", `/checkins/${id}`, { status: "resolved" }, a.token))
      .data.status,
    "resolved",
  );
  await f.app.store.run(
    "UPDATE checkins SET status='pending',due_at=? WHERE id=?",
    Date.now() - 1,
    id,
  );
  assert.equal(
    (await f.call("GET", `/checkins/${id}`, undefined, a.token)).data.overdue,
    true,
  );
  assert.equal(
    (await f.call("DELETE", `/checkins/${id}`, undefined, a.token)).status,
    200,
  );
  assert.equal(
    (await f.call("GET", "/checkins", undefined, a.token)).data.items.length,
    0,
  );
});
test("OpenAPI contains all secured CRUD routes and unauthenticated requests are denied", async (t) => {
  const f = await fixture(t),
    doc = f.app.swagger();
  for (const path of [
    "/contacts",
    "/contacts/{id}",
    "/checkins",
    "/checkins/{id}",
    "/users",
    "/users/{id}",
    "/me",
  ]) {
    assert.ok(doc.paths[path]);
    for (const op of Object.values(doc.paths[path]))
      assert.deepEqual(op.security, [{ bearerAuth: [] }]);
  }
  assert.equal((await f.call("GET", "/contacts")).status, 401);
  assert.equal((await f.call("GET", "/health")).data.status, "ok");
  assert.equal((await f.app.inject("/docs/")).statusCode, 200);
});
test("SMTP failure never exposes a code or grants a session", async (t) => {
  const f = await fixture(t);
  const user = await f.seed();
  // Replacing a fixture mailer is unnecessary: a fresh app provides the failing boundary.
  const app = await buildApp(
    {
      databasePath: ":memory:",
      jwtSecret: "j".repeat(64),
      otpSecret: "o".repeat(64),
      publicUrl: "https://motion-api.vihx.online",
    },
    {
      mailer: {
        sendMail: async () => {
          throw new Error("offline");
        },
      },
    },
  );
  t.after(() => app.close());
  const r = await app.inject({
    method: "POST",
    url: "/auth/register",
    payload: { email: user.email, name: "x", password: f.pass },
  });
  assert.equal(r.statusCode, 503);
  assert.equal(
    (await app.store.one("SELECT COUNT(*) AS n FROM sessions")).n,
    0,
  );
  assert.equal((await app.store.one("SELECT used FROM challenges")).used, 1);
});
test("auth endpoint rate limit rejects repeated password attempts", async (t) => {
  const f = await fixture(t);
  for (let i = 0; i < 12; i++)
    assert.equal(
      (
        await f.call("POST", "/auth/login", {
          email: "none@example.org",
          password: "wrong",
        })
      ).status,
      401,
    );
  assert.equal(
    (
      await f.call("POST", "/auth/login", {
        email: "none@example.org",
        password: "wrong",
      })
    ).status,
    429,
  );
});
test("admin-created account activates through mailbox reset; unknown/reset cooldown have same public envelope", async (t) => {
  const f = await fixture(t),
    admin = await f.seed("admin");
  const created = await f.call(
    "POST",
    "/users",
    {
      email: "invite@example.org",
      name: "Invited",
      password: f.pass,
      role: "staff",
    },
    admin.token,
  );
  assert.equal(created.data.verified, false);
  const reset = await f.call("POST", "/auth/forgot-password", {
      email: "invite@example.org",
    }),
    code = f.code();
  const repeat = await f.call("POST", "/auth/forgot-password", {
    email: "invite@example.org",
  });
  const missing = await f.call("POST", "/auth/forgot-password", {
    email: "absent@example.org",
  });
  assert.equal(reset.status, missing.status);
  assert.equal(reset.data.message, missing.data.message);
  assert.equal(repeat.status, 200);
  assert.equal(repeat.data.challengeId, reset.data.challengeId);
  assert.equal(
    (
      await f.call("POST", "/auth/reset-password", {
        challengeId: reset.data.challengeId,
        code,
        password: "my-own-new-password",
      })
    ).status,
    200,
  );
  assert.equal(
    (
      await f.call("POST", "/auth/login", {
        email: "invite@example.org",
        password: "my-own-new-password",
      })
    ).status,
    200,
  );
});
test("reassignment immediately removes old staff access, even with an existing session", async (t) => {
  const f = await fixture(t),
    admin = await f.seed("admin"),
    first = await f.seed("staff"),
    second = await f.seed("staff"),
    member = await f.seed();
  await f.call(
    "PATCH",
    `/users/${member.id}`,
    { assignedStaffId: first.id },
    admin.token,
  );
  const contact = await f.call(
    "POST",
    "/contacts",
    { ownerId: member.id, name: "x", phone: "0912345678" },
    first.token,
  );
  await f.call(
    "PATCH",
    `/users/${member.id}`,
    { assignedStaffId: second.id },
    admin.token,
  );
  assert.equal(
    (
      await f.call(
        "GET",
        `/contacts/${contact.data.id}`,
        undefined,
        first.token,
      )
    ).status,
    404,
  );
  assert.equal(
    (
      await f.call(
        "GET",
        `/contacts/${contact.data.id}`,
        undefined,
        second.token,
      )
    ).status,
    200,
  );
});
test("self deletion verifies password and cascades cloud records without touching device state", async (t) => {
  const f = await fixture(t),
    member = await f.seed();
  await f.call(
    "POST",
    "/contacts",
    { name: "x", phone: "0912345678" },
    member.token,
  );
  await f.call(
    "POST",
    "/checkins",
    { title: "x", dueAt: Date.now() + 60000 },
    member.token,
  );
  assert.equal(
    (await f.call("DELETE", "/me", { password: "wrong" }, member.token)).status,
    403,
  );
  assert.equal(
    (await f.call("DELETE", "/me", { password: f.pass }, member.token)).status,
    200,
  );
  assert.equal(
    (await f.app.store.one("SELECT COUNT(*) AS n FROM contacts")).n,
    0,
  );
  assert.equal(
    (await f.app.store.one("SELECT COUNT(*) AS n FROM checkins")).n,
    0,
  );
  assert.equal(
    (await f.call("GET", "/me", undefined, member.token)).status,
    401,
  );
});
