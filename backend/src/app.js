import Fastify from "fastify";
import jwt from "@fastify/jwt";
import rateLimit from "@fastify/rate-limit";
import swagger from "@fastify/swagger";
import swaggerUi from "@fastify/swagger-ui";
import { randomUUID } from "node:crypto";
import { storeFromConfig, publicUser } from "./store.js";
import { createMailer } from "./mailer.js";
import {
  hashPassword,
  verifyPassword,
  newOtp,
  otpDigest,
  validOtp,
} from "./security.js";
import { responses } from "./schemas.js";

const str = (maxLength, minLength = 1) => ({
  type: "string",
  minLength,
  maxLength,
});
const email = { type: "string", format: "email", maxLength: 254 };
const password = str(128, 10);
const idParam = {
  type: "object",
  required: ["id"],
  properties: { id: { type: "string", format: "uuid" } },
};
const body = (properties, required = Object.keys(properties)) => ({
  type: "object",
  additionalProperties: false,
  required,
  properties,
});
const codeFields = {
  challengeId: { type: "string", format: "uuid" },
  code: { type: "string", pattern: "^\\d{6}$" },
};
const safe = { security: [{ bearerAuth: [] }] };
function fail(status, message) {
  throw Object.assign(new Error(message), { statusCode: status });
}
const cleanEmail = (value) => value.trim().toLowerCase();
const label = (value) => value.trim();
function normalizePhone(value) {
  let phone = value.replace(/[\s().-]/g, "");
  if (phone.startsWith("+84")) phone = `0${phone.slice(3)}`;
  if (!/^(0\d{8,10}|\+[1-9]\d{7,14})$/.test(phone))
    fail(400, "Số điện thoại không hợp lệ.");
  if (["113", "114", "115"].includes(phone))
    fail(400, "Không thêm số khẩn cấp vào danh sách gửi tự động.");
  return phone;
}

export async function buildApp(config, overrides = {}) {
  const app = Fastify({
    logger: overrides.logger ?? false,
    bodyLimit: 32 * 1024,
    // Exactly one ingress: host Caddy -> loopback Docker port -> API.
    // Inside Docker the host has a bridge IP, not 127.0.0.1. Never expose 3000.
    // Caddy replaces untrusted incoming X-Forwarded-For by default.
    trustProxy: 1,
    ajv: { customOptions: { removeAdditional: false } },
  });
  const store = overrides.store ?? (await storeFromConfig(config));
  const transport = overrides.mailer ?? createMailer(config);
  const dummyHash = await hashPassword(randomUUID());
  app.decorate("store", store);
  await app.register(rateLimit, { max: 120, timeWindow: "1 minute" });
  await app.register(jwt, {
    secret: config.jwtSecret,
    sign: { expiresIn: "12h", iss: "motion-api", aud: "motion-app" },
    verify: { allowedIss: "motion-api", allowedAud: "motion-app" },
  });
  await app.register(swagger, {
    openapi: {
      openapi: "3.0.3",
      info: {
        title: "Motion API",
        version: "1.0.0",
        description:
          "Đăng ký email, mật khẩu + Email OTP, RBAC và Vòng an toàn. SOS qua SIM chạy tại thiết bị; API không tự gọi/gửi SMS.",
      },
      servers: [{ url: config.publicUrl }],
      tags: [
        "Auth",
        "Account",
        "Admin",
        "Contacts",
        "Safety circle",
        "Health",
      ].map((name) => ({ name })),
      components: {
        securitySchemes: {
          bearerAuth: { type: "http", scheme: "bearer", bearerFormat: "JWT" },
        },
      },
    },
  });
  await app.register(swaggerUi, { routePrefix: "/docs" });
  app.setErrorHandler((error, request, reply) => {
    let status = error.statusCode || 500;
    if (
      String(error.code).startsWith("SQLITE_CONSTRAINT") ||
      [1555, 2067, 787].includes(error.errcode) ||
      ["23505", "23503", "40001", "40P01"].includes(error.code)
    )
      status = 409;
    if (status >= 500) request.log.error({ err: error }, "Request failed");
    reply.code(status).send({
      message:
        status >= 500
          ? "Dịch vụ đang bận. Vui lòng thử lại."
          : status === 409
            ? "Dữ liệu trùng lặp hoặc xung đột."
            : error.validation
              ? "Dữ liệu không hợp lệ."
              : error.message,
    });
  });
  app.addHook("onClose", async () => await store.close());

  const authenticated = async (request) => {
    try {
      await request.jwtVerify();
    } catch {
      fail(401, "Phiên đăng nhập không hợp lệ hoặc đã hết hạn.");
    }
    const session = await store.one(
      "SELECT * FROM sessions WHERE id=? AND user_id=? AND expires_at>?",
      request.user.sid,
      request.user.sub,
      Date.now(),
    );
    const user = await store.one(
      "SELECT * FROM users WHERE id=?",
      request.user.sub,
    );
    if (!session || !user?.active || !user.verified)
      fail(401, "Phiên đăng nhập đã bị thu hồi.");
    // Current DB role is authoritative, never a stale JWT role or client field.
    request.account = user;
  };
  const admin = async (request) => {
    await authenticated(request);
    if (request.account.role !== "admin") fail(403, "Cần quyền quản trị viên.");
  };
  async function mayAccess(actor, ownerId) {
    if (actor.id === ownerId || actor.role === "admin") return true;
    return (
      actor.role === "staff" &&
      !!(await store.one(
        "SELECT id FROM users WHERE id=? AND role='member' AND assigned_staff_id=?",
        ownerId,
        actor.id,
      ))
    );
  }
  const checkAuthLimit = app.createRateLimit({
    max: 12,
    timeWindow: "15 minutes",
    keyGenerator: (request) =>
      `${request.ip}:${request.routeOptions.url}:${typeof request.body?.email === "string" ? cleanEmail(request.body.email) : (request.body?.challengeId ?? "anonymous")}`,
  });
  const authLimiter = async (request, reply) => {
    const limit = await checkAuthLimit(request);
    if (!limit.isAllowed && limit.isExceeded) {
      reply.header("Retry-After", limit.ttlInSeconds);
      fail(429, "Đã thử quá nhiều lần. Vui lòng đợi trước khi thử lại.");
    }
  };
  async function issueChallenge(user, purpose) {
    const now = Date.now();
    const latest = await store.one(
      "SELECT created_at FROM challenges WHERE user_id=? AND purpose=? ORDER BY created_at DESC LIMIT 1",
      user.id,
      purpose,
    );
    if (latest && now - latest.created_at < 60_000)
      fail(429, "Vui lòng đợi 60 giây trước khi xin mã mới.");
    const id = randomUUID(),
      code = newOtp();
    await store.transaction(async () => {
      await store.run(
        "UPDATE challenges SET used=1 WHERE user_id=? AND purpose=? AND used=0",
        user.id,
        purpose,
      );
      await store.run(
        "INSERT INTO challenges(id,user_id,purpose,digest,expires_at,created_at) VALUES(?,?,?,?,?,?)",
        id,
        user.id,
        purpose,
        otpDigest(config.otpSecret, id, code),
        now + 300_000,
        now,
      );
    });
    try {
      await transport.sendMail({
        from: config.mailFrom,
        to: user.email,
        subject: `Motion · ${purpose === "login" ? "Mã đăng nhập" : purpose === "reset" ? "Đặt lại mật khẩu" : "Xác thực email"}`,
        text: `Mã xác thực Motion: ${code}\nMã có hiệu lực 5 phút, chỉ dùng một lần. Không chia sẻ mã. Nếu không yêu cầu, hãy bỏ qua email này.`,
      });
    } catch {
      await store.run("UPDATE challenges SET used=1 WHERE id=?", id);
      fail(503, "Chưa gửi được email xác thực. Vui lòng thử lại sau.");
    }
    return {
      challengeId: id,
      expiresIn: 300,
      message: "Kiểm tra email để lấy mã xác thực.",
    };
  }
  async function consumeChallenge(id, code, purpose) {
    // Synchronous transaction: attempts and use-once state cannot race across requests.
    return await store.transaction(async () => {
      const challenge = await store.one(
        "SELECT * FROM challenges WHERE id=? AND purpose=?",
        id,
        purpose,
      );
      if (
        !challenge ||
        challenge.used ||
        challenge.expires_at <= Date.now() ||
        challenge.attempts >= 5
      )
        return null;
      await store.run(
        "UPDATE challenges SET attempts=attempts+1 WHERE id=?",
        id,
      );
      if (!validOtp(config.otpSecret, challenge, code)) return null;
      await store.run("UPDATE challenges SET used=1 WHERE id=?", id);
      return await store.one(
        "SELECT * FROM users WHERE id=? AND active=1",
        challenge.user_id,
      );
    });
  }
  const genericChallenge = () => ({
    challengeId: randomUUID(),
    expiresIn: 300,
    message: "Nếu tài khoản phù hợp, mã xác thực sẽ được gửi qua email.",
  });
  async function sessionFor(user) {
    const sid = randomUUID();
    await store.run("DELETE FROM sessions WHERE expires_at<=?", Date.now());
    await store.run(
      "INSERT INTO sessions(id,user_id,expires_at) VALUES(?,?,?)",
      sid,
      user.id,
      Date.now() + 43_200_000,
    );
    return {
      accessToken: await app.jwt.sign({ sub: user.id, sid }),
      expiresIn: 43_200,
      user: publicUser(user),
    };
  }
  function route(method, url, tag, summary, schema, handler, preHandler) {
    app.route({
      method,
      url,
      config: {},
      schema: {
        tags: [tag],
        summary,
        response: responses(method, url),
        ...schema,
      },
      preHandler: tag === "Auth" ? authLimiter : preHandler,
      handler,
    });
  }
  route(
    "GET",
    "/health",
    "Health",
    "Kiểm tra API và cơ sở dữ liệu",
    {},
    async () => {
      await store.one("SELECT 1");
      return { status: "ok", service: "motion-api" };
    },
  );
  route(
    "POST",
    "/auth/register",
    "Auth",
    "Đăng ký tài khoản email (chỉ vai trò người dùng)",
    { body: body({ email, name: str(80), password }) },
    async (request) => {
      const data = request.body,
        normalized = cleanEmail(data.email);
      if (!label(data.name)) fail(400, "Tên không được để trống.");
      let user = await store.one(
        "SELECT * FROM users WHERE email=?",
        normalized,
      );
      if (user) {
        if (!user.verified && user.active)
          return issueChallenge(user, "verify");
        return genericChallenge();
      }
      const id = randomUUID();
      await store.run(
        "INSERT INTO users(id,email,name,password,created_at) VALUES(?,?,?,?,?)",
        id,
        normalized,
        label(data.name),
        await hashPassword(data.password),
        Date.now(),
      );
      user = await store.one("SELECT * FROM users WHERE id=?", id);
      return issueChallenge(user, "verify");
    },
  );
  route(
    "POST",
    "/auth/verify-email",
    "Auth",
    "Xác thực email bằng OTP; sau đó đăng nhập",
    { body: body(codeFields) },
    async (request) => {
      const user = await consumeChallenge(
        request.body.challengeId,
        request.body.code,
        "verify",
      );
      if (!user) fail(400, "Mã không đúng, hết hạn hoặc đã được dùng.");
      await store.run("UPDATE users SET verified=1 WHERE id=?", user.id);
      return { message: "Email đã được xác thực. Bạn có thể đăng nhập." };
    },
  );
  route(
    "POST",
    "/auth/login",
    "Auth",
    "Bước 1: email + mật khẩu, gửi Email OTP",
    { body: body({ email, password: str(128) }) },
    async (request) => {
      const user = await store.one(
        "SELECT * FROM users WHERE email=?",
        cleanEmail(request.body.email),
      );
      const valid = await verifyPassword(
        request.body.password,
        user?.password ?? dummyHash,
      );
      if (!user?.active || !user.verified || !valid)
        fail(401, "Email hoặc mật khẩu không đúng, hoặc email chưa xác thực.");
      return issueChallenge(user, "login");
    },
  );
  route(
    "POST",
    "/auth/login/verify",
    "Auth",
    "Bước 2: Email OTP, cấp phiên JWT",
    { body: body(codeFields) },
    async (request) => {
      const user = await consumeChallenge(
        request.body.challengeId,
        request.body.code,
        "login",
      );
      if (!user?.verified)
        fail(400, "Mã không đúng, hết hạn hoặc đã được dùng.");
      return sessionFor(user);
    },
  );
  route(
    "POST",
    "/auth/forgot-password",
    "Auth",
    "Xin mã đặt lại mật khẩu (không tiết lộ tài khoản tồn tại)",
    { body: body({ email }) },
    async (request) => {
      const user = await store.one(
        "SELECT * FROM users WHERE email=? AND active=1",
        cleanEmail(request.body.email),
      );
      if (!user) return genericChallenge();
      try {
        const challenge = await issueChallenge(user, "reset");
        return { ...challenge, message: genericChallenge().message };
      } catch (e) {
        // Return the same public envelope for an unknown mailbox, resend cooldown,
        // or SMTP error. Only the owner of the mailbox can complete a real challenge.
        if (e.statusCode === 429) {
          const pending = await store.one(
            "SELECT id FROM challenges WHERE user_id=? AND purpose='reset' AND used=0 AND attempts<5 AND expires_at>? ORDER BY created_at DESC LIMIT 1",
            user.id,
            Date.now(),
          );
          if (pending)
            return { ...genericChallenge(), challengeId: pending.id };
        }
        if ([429, 503].includes(e.statusCode)) return genericChallenge();
        throw e;
      }
    },
  );
  route(
    "POST",
    "/auth/reset-password",
    "Auth",
    "Đặt mật khẩu mới và thu hồi mọi phiên",
    { body: body({ ...codeFields, password }) },
    async (request) => {
      // Hash first; consume and change password together without an async gap.
      const encoded = await hashPassword(request.body.password);
      const user = await consumeChallenge(
        request.body.challengeId,
        request.body.code,
        "reset",
      );
      if (!user) fail(400, "Mã không đúng, hết hạn hoặc đã được dùng.");
      await store.transaction(async () => {
        await store.run(
          "UPDATE users SET password=?,verified=1 WHERE id=?",
          encoded,
          user.id,
        );
        await store.run("DELETE FROM sessions WHERE user_id=?", user.id);
        await store.run(
          "UPDATE challenges SET used=1 WHERE user_id=?",
          user.id,
        );
      });
      return { message: "Đã đặt lại mật khẩu. Hãy đăng nhập lại." };
    },
  );
  route(
    "POST",
    "/auth/logout",
    "Account",
    "Đăng xuất và thu hồi phiên hiện tại",
    safe,
    async (request) => {
      await store.run("DELETE FROM sessions WHERE id=?", request.user.sid);
      return { message: "Đã đăng xuất." };
    },
    authenticated,
  );
  route(
    "GET",
    "/me",
    "Account",
    "Thông tin tài khoản và vai trò hiện tại",
    safe,
    async (request) => publicUser(request.account),
    authenticated,
  );
  route(
    "PATCH",
    "/me",
    "Account",
    "Cập nhật tên hiển thị",
    { ...safe, body: body({ name: str(80) }) },
    async (request) => {
      if (!label(request.body.name)) fail(400, "Tên không được để trống.");
      await store.run(
        "UPDATE users SET name=? WHERE id=?",
        label(request.body.name),
        request.account.id,
      );
      return publicUser(
        await store.one("SELECT * FROM users WHERE id=?", request.account.id),
      );
    },
    authenticated,
  );
  async function protectLastAdmin(user, nextRole, nextActive) {
    if (
      user.role === "admin" &&
      user.active &&
      (nextRole !== "admin" || !nextActive) &&
      (
        await store.one(
          "SELECT COUNT(*) AS n FROM users WHERE role='admin' AND active=1",
        )
      ).n <= 1
    )
      fail(409, "Không thể xóa hoặc hạ quyền quản trị viên cuối cùng.");
  }
  route(
    "DELETE",
    "/me",
    "Account",
    "Xóa tài khoản và toàn bộ dữ liệu đám mây (xác nhận mật khẩu)",
    { ...safe, body: body({ password: str(128) }) },
    async (request) => {
      if (
        !(await verifyPassword(request.body.password, request.account.password))
      )
        fail(403, "Mật khẩu không đúng.");
      await store.transaction(async () => {
        const current = await store.one(
          "SELECT * FROM users WHERE id=?",
          request.account.id,
        );
        if (!current) fail(404, "Không tìm thấy tài khoản.");
        await protectLastAdmin(current, "", false);
        await store.run("DELETE FROM users WHERE id=?", current.id);
      });
      return {
        message:
          "Đã xóa tài khoản và dữ liệu đám mây. Dữ liệu SOS trên máy không bị xóa.",
      };
    },
    authenticated,
  );
  route(
    "GET",
    "/users",
    "Account",
    "Admin: toàn bộ tài khoản; nhân viên: người được phân công; người dùng: chính mình",
    safe,
    async (request) => {
      const actor = request.account;
      const rows =
        actor.role === "admin"
          ? await store.all(
              "SELECT * FROM users ORDER BY created_at DESC LIMIT 500",
            )
          : actor.role === "staff"
            ? await store.all(
                "SELECT * FROM users WHERE id=? OR assigned_staff_id=? ORDER BY name LIMIT 500",
                actor.id,
                actor.id,
              )
            : [actor];
      return { items: rows.map(publicUser) };
    },
    authenticated,
  );
  route(
    "GET",
    "/users/:id",
    "Account",
    "Xem tài khoản của mình hoặc người được phân công",
    { ...safe, params: idParam },
    async (request) => {
      const user = await store.one(
        "SELECT * FROM users WHERE id=?",
        request.params.id,
      );
      if (!user || !(await mayAccess(request.account, user.id)))
        fail(404, "Không tìm thấy tài khoản.");
      return publicUser(user);
    },
    authenticated,
  );
  route(
    "POST",
    "/users",
    "Admin",
    "Tạo tài khoản (người nhận phải xác thực email)",
    {
      ...safe,
      body: body({
        email,
        name: str(80),
        password,
        role: { type: "string", enum: ["admin", "staff", "member"] },
      }),
    },
    async (request) => {
      const d = request.body;
      if (!label(d.name)) fail(400, "Tên không được để trống.");
      if (
        await store.one(
          "SELECT id FROM users WHERE email=?",
          cleanEmail(d.email),
        )
      )
        fail(409, "Email đã tồn tại.");
      const id = randomUUID();
      await store.run(
        "INSERT INTO users(id,email,name,password,role,created_at) VALUES(?,?,?,?,?,?)",
        id,
        cleanEmail(d.email),
        label(d.name),
        await hashPassword(d.password),
        d.role,
        Date.now(),
      );
      return publicUser(await store.one("SELECT * FROM users WHERE id=?", id));
    },
    admin,
  );
  route(
    "PATCH",
    "/users/:id",
    "Admin",
    "Đổi tên, vai trò, trạng thái và phân công nhân viên",
    {
      ...safe,
      params: idParam,
      body: body(
        {
          name: str(80),
          role: { type: "string", enum: ["admin", "staff", "member"] },
          active: { type: "boolean" },
          assignedStaffId: {
            anyOf: [{ type: "string", format: "uuid" }, { type: "null" }],
          },
        },
        [],
      ),
    },
    async (request) => {
      const user = await store.one(
        "SELECT * FROM users WHERE id=?",
        request.params.id,
      );
      if (!user) fail(404, "Không tìm thấy tài khoản.");
      const d = request.body,
        role = d.role ?? user.role,
        active = d.active ?? !!user.active;
      const assigned =
        d.assignedStaffId === undefined
          ? user.assigned_staff_id
          : d.assignedStaffId;
      if (
        assigned &&
        (role !== "member" ||
          !(await store.one(
            "SELECT id FROM users WHERE id=? AND role='staff' AND active=1",
            assigned,
          )))
      )
        fail(400, "Chỉ phân công người dùng cho nhân viên đang hoạt động.");
      if (d.name !== undefined && !label(d.name))
        fail(400, "Tên không được để trống.");
      await store.transaction(async () => {
        const current = await store.one(
          "SELECT * FROM users WHERE id=?",
          user.id,
        );
        if (
          !current ||
          current.role !== user.role ||
          current.active !== user.active
        )
          fail(409, "Tài khoản vừa thay đổi. Hãy tải lại.");
        await protectLastAdmin(current, role, active);
        await store.run(
          "UPDATE users SET name=?,role=?,active=?,assigned_staff_id=? WHERE id=?",
          d.name === undefined ? user.name : label(d.name),
          role,
          active ? 1 : 0,
          assigned,
          user.id,
        );
        if (user.role === "staff" && (role !== "staff" || !active))
          await store.run(
            "UPDATE users SET assigned_staff_id=NULL WHERE assigned_staff_id=?",
            user.id,
          );
        if (!active || role !== user.role) {
          await store.run("DELETE FROM sessions WHERE user_id=?", user.id);
          await store.run(
            "UPDATE challenges SET used=1 WHERE user_id=?",
            user.id,
          );
        }
      });
      return publicUser(
        await store.one("SELECT * FROM users WHERE id=?", user.id),
      );
    },
    admin,
  );
  route(
    "DELETE",
    "/users/:id",
    "Admin",
    "Xóa tài khoản và dữ liệu liên quan",
    { ...safe, params: idParam },
    async (request) => {
      const user = await store.one(
        "SELECT * FROM users WHERE id=?",
        request.params.id,
      );
      if (!user) fail(404, "Không tìm thấy tài khoản.");
      await store.transaction(async () => {
        const current = await store.one(
          "SELECT * FROM users WHERE id=?",
          user.id,
        );
        if (!current) fail(404, "Không tìm thấy tài khoản.");
        await protectLastAdmin(current, "", false);
        await store.run("DELETE FROM users WHERE id=?", user.id);
      });
      return { message: "Đã xóa tài khoản." };
    },
    admin,
  );

  // The same owner check covers list/read/create/update/delete, including guessed UUIDs.
  const ownerQuery = {
    type: "object",
    additionalProperties: false,
    properties: { ownerId: { type: "string", format: "uuid" } },
  };
  const ownerField = { type: "string", format: "uuid" };
  async function ownerFor(request, explicit) {
    const id = explicit ?? request.account.id;
    if (!(await mayAccess(request.account, id)))
      fail(403, "Bạn không được truy cập dữ liệu của người này.");
    if (!(await store.one("SELECT id FROM users WHERE id=?", id)))
      fail(404, "Không tìm thấy người dùng.");
    return id;
  }
  async function rowFor(request, table) {
    const row = await store.one(
      `SELECT * FROM ${table} WHERE id=?`,
      request.params.id,
    );
    if (!row || !(await mayAccess(request.account, row.owner_id)))
      fail(404, "Không tìm thấy dữ liệu.");
    return row;
  }
  const mapContact = (r) => ({
    id: r.id,
    ownerId: r.owner_id,
    name: r.name,
    phone: r.phone,
    relationship: r.relationship,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  });
  const mapCheckin = (r) => ({
    id: r.id,
    ownerId: r.owner_id,
    title: r.title,
    dueAt: r.due_at,
    status: r.status,
    note: r.note,
    overdue: r.status === "pending" && r.due_at < Date.now(),
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  });
  for (const [table, tag, map] of [
    ["contacts", "Contacts", mapContact],
    ["checkins", "Safety circle", mapCheckin],
  ]) {
    route(
      "GET",
      `/${table}`,
      tag,
      "Danh sách của bản thân hoặc người được phân công",
      { ...safe, querystring: ownerQuery },
      async (request) => {
        const owner = await ownerFor(request, request.query.ownerId);
        return {
          items: (
            await store.all(
              `SELECT * FROM ${table} WHERE owner_id=? ORDER BY created_at DESC LIMIT 500`,
              owner,
            )
          ).map(map),
        };
      },
      authenticated,
    );
    route(
      "GET",
      `/${table}/:id`,
      tag,
      "Xem chi tiết (kiểm tra chủ sở hữu)",
      { ...safe, params: idParam },
      async (request) => map(await rowFor(request, table)),
      authenticated,
    );
    route(
      "DELETE",
      `/${table}/:id`,
      tag,
      "Xóa bản ghi (kiểm tra chủ sở hữu)",
      { ...safe, params: idParam },
      async (request) => {
        const row = await rowFor(request, table);
        await store.run(`DELETE FROM ${table} WHERE id=?`, row.id);
        return { message: "Đã xóa." };
      },
      authenticated,
    );
  }
  const contactFields = {
    name: str(80),
    phone: str(30),
    relationship: str(80, 0),
  };
  route(
    "POST",
    "/contacts",
    "Contacts",
    "Tạo liên hệ đám mây (không tự thay đổi người nhận SOS trên máy)",
    {
      ...safe,
      body: body({ ...contactFields, ownerId: ownerField }, ["name", "phone"]),
    },
    async (request) => {
      const d = request.body,
        owner = await ownerFor(request, d.ownerId),
        id = randomUUID(),
        now = Date.now();
      if (!label(d.name)) fail(400, "Tên không được để trống.");
      if (
        (
          await store.one(
            "SELECT COUNT(*) AS n FROM contacts WHERE owner_id=?",
            owner,
          )
        ).n >= 100
      )
        fail(409, "Tối đa 100 liên hệ đám mây.");
      await store.run(
        "INSERT INTO contacts(id,owner_id,name,phone,relationship,created_at,updated_at) VALUES(?,?,?,?,?,?,?)",
        id,
        owner,
        label(d.name),
        normalizePhone(d.phone),
        label(d.relationship ?? ""),
        now,
        now,
      );
      return mapContact(
        await store.one("SELECT * FROM contacts WHERE id=?", id),
      );
    },
    authenticated,
  );
  route(
    "PATCH",
    "/contacts/:id",
    "Contacts",
    "Sửa liên hệ",
    { ...safe, params: idParam, body: body(contactFields, []) },
    async (request) => {
      const row = await rowFor(request, "contacts"),
        d = request.body;
      if (d.name !== undefined && !label(d.name))
        fail(400, "Tên không được để trống.");
      await store.run(
        "UPDATE contacts SET name=?,phone=?,relationship=?,updated_at=? WHERE id=?",
        d.name === undefined ? row.name : label(d.name),
        d.phone === undefined ? row.phone : normalizePhone(d.phone),
        d.relationship === undefined ? row.relationship : label(d.relationship),
        Date.now(),
        row.id,
      );
      return mapContact(
        await store.one("SELECT * FROM contacts WHERE id=?", row.id),
      );
    },
    authenticated,
  );
  const checkinFields = {
    title: str(120),
    dueAt: { type: "integer", minimum: 1, maximum: 8640000000000000 },
    status: {
      type: "string",
      enum: ["pending", "safe", "needs_help", "resolved"],
    },
    note: str(1000, 0),
  };
  route(
    "POST",
    "/checkins",
    "Safety circle",
    "Tạo lịch hẹn xác nhận an toàn; không tự kích hoạt SOS",
    {
      ...safe,
      body: body({ ...checkinFields, ownerId: ownerField }, ["title", "dueAt"]),
    },
    async (request) => {
      const d = request.body,
        owner = await ownerFor(request, d.ownerId),
        id = randomUUID(),
        now = Date.now();
      if (!label(d.title) || d.dueAt < now)
        fail(400, "Nhập tiêu đề và thời gian trong tương lai.");
      if (
        (
          await store.one(
            "SELECT COUNT(*) AS n FROM checkins WHERE owner_id=?",
            owner,
          )
        ).n >= 500
      )
        fail(409, "Tối đa 500 lịch hẹn. Hãy xóa lịch cũ trước.");
      await store.run(
        "INSERT INTO checkins(id,owner_id,title,due_at,status,note,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?)",
        id,
        owner,
        label(d.title),
        d.dueAt,
        d.status ?? "pending",
        label(d.note ?? ""),
        now,
        now,
      );
      return mapCheckin(
        await store.one("SELECT * FROM checkins WHERE id=?", id),
      );
    },
    authenticated,
  );
  route(
    "PATCH",
    "/checkins/:id",
    "Safety circle",
    "Sửa lịch hẹn hoặc ghi nhận an toàn/hỗ trợ",
    { ...safe, params: idParam, body: body(checkinFields, []) },
    async (request) => {
      const row = await rowFor(request, "checkins"),
        d = request.body;
      if (d.title !== undefined && !label(d.title))
        fail(400, "Tiêu đề không được để trống.");
      if (d.dueAt !== undefined && d.dueAt < Date.now())
        fail(400, "Thời gian mới phải ở tương lai.");
      await store.run(
        "UPDATE checkins SET title=?,due_at=?,status=?,note=?,updated_at=? WHERE id=?",
        d.title === undefined ? row.title : label(d.title),
        d.dueAt ?? row.due_at,
        d.status ?? row.status,
        d.note === undefined ? row.note : label(d.note),
        Date.now(),
        row.id,
      );
      return mapCheckin(
        await store.one("SELECT * FROM checkins WHERE id=?", row.id),
      );
    },
    authenticated,
  );
  return app;
}
