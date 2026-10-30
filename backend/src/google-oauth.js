import {
  createHash,
  randomBytes,
  randomUUID,
  timingSafeEqual,
} from "node:crypto";
import { OAuth2Client } from "google-auth-library";
import { hashPassword } from "./security.js";

const random = () => randomBytes(32).toString("base64url");
const digest = (value) =>
  createHash("sha256").update(value).digest("base64url");
const same = (a, b) => {
  if (typeof a !== "string" || typeof b !== "string") return false;
  const left = Buffer.from(a),
    right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
};
const object = (properties, required = Object.keys(properties)) => ({
  type: "object",
  additionalProperties: false,
  properties,
  required,
});
const id = { type: "string", format: "uuid" };
const verifier = { type: "string", pattern: "^[A-Za-z0-9._~-]{43,128}$" };
const fail = (statusCode, message) => {
  throw Object.assign(new Error(message), {
    statusCode,
    publicMessage: statusCode === 503,
  });
};
const appCallback = "com.vihx.motion://oauth/google";

export function googleProvider(config) {
  const redirect = new URL("/auth/google/callback", config.publicUrl).href;
  const client = new OAuth2Client({
    clientId: config.googleClientId,
    clientSecret: config.googleClientSecret,
    redirectUri: redirect,
    transporterOptions: { timeout: 15_000 },
  });
  return {
    authorizationUrl({ state, nonce, codeChallenge }) {
      return client.generateAuthUrl({
        scope: ["openid", "email", "profile"],
        state,
        nonce,
        code_challenge: codeChallenge,
        code_challenge_method: "S256",
        prompt: "select_account",
        access_type: "online",
      });
    },
    async exchange(code, codeVerifier) {
      const { tokens } = await client.getToken({ code, codeVerifier });
      if (!tokens.id_token) throw new Error("Missing Google ID token");
      const ticket = await client.verifyIdToken({
        idToken: tokens.id_token,
        audience: config.googleClientId,
      });
      return ticket.getPayload();
    },
  };
}

export async function registerGoogleOAuth(
  app,
  { store, config, authenticated, sessionFor, provider },
) {
  const enabled = !!config.googleClientId && !!config.googleClientSecret;
  const google = provider ?? (enabled ? googleProvider(config) : null);
  const schemaModels = {
    GoogleOAuthStartRequest: object(
      {
        codeChallenge: { type: "string", pattern: "^[A-Za-z0-9_-]{43}$" },
        linkAccount: { type: "boolean", default: false },
      },
      ["codeChallenge"],
    ),
    GoogleOAuthStartResponse: object({
      flowId: id,
      authorizationUrl: { type: "string", format: "uri" },
      expiresIn: { type: "integer" },
    }),
    GoogleOAuthExchangeRequest: object({
      flowId: id,
      ticket: { type: "string", pattern: "^[A-Za-z0-9_-]{43}$" },
      codeVerifier: verifier,
    }),
  };
  for (const [name, schema] of Object.entries(schemaModels))
    app.addSchema({ $id: name, title: name, ...schema });
  const noCache = async (_request, reply) => {
    reply
      .header("Cache-Control", "no-store")
      .header("Referrer-Policy", "no-referrer");
  };
  const requireEnabled = () => {
    if (!enabled)
      fail(503, "Đăng nhập Google chưa sẵn sàng. Hãy đăng nhập bằng email.");
  };
  const returnToApp = (reply, flowId, values) => {
    const uri = new URL(appCallback);
    uri.search = new URLSearchParams({ flowId, ...values }).toString();
    return reply.code(302).header("Location", uri.href).send();
  };
  const errors = Object.fromEntries(
    [400, 401, 403, 409, 429, 503].map((code) => [
      code,
      { $ref: "MessageResponse#" },
    ]),
  );
  app.post(
    "/auth/google/start",
    {
      onRequest: noCache,
      schema: {
        tags: ["Auth"],
        security: [{}, { bearerAuth: [] }],
        summary:
          "Bắt đầu Google OAuth2/OIDC với PKCE; linkAccount cần phiên đăng nhập",
        body: { $ref: "GoogleOAuthStartRequest#" },
        response: { 200: { $ref: "GoogleOAuthStartResponse#" }, ...errors },
      },
    },
    async (request) => {
      requireEnabled();
      let linkUser = null,
        linkSession = null;
      if (request.body.linkAccount) {
        await authenticated(request);
        linkUser = request.account.id;
        linkSession = request.user.sid;
      }
      const flowId = randomUUID(),
        state = random(),
        nonce = random(),
        googleVerifier = random(),
        now = Date.now();
      await store.run(
        "DELETE FROM google_oauth_flows WHERE expires_at<=?",
        now,
      );
      await store.run(
        "INSERT INTO google_oauth_flows(id,state_digest,nonce,google_verifier,app_challenge,link_user_id,link_session_id,expires_at) VALUES(?,?,?,?,?,?,?,?)",
        flowId,
        digest(state),
        nonce,
        googleVerifier,
        request.body.codeChallenge,
        linkUser,
        linkSession,
        now + 600_000,
      );
      return {
        flowId,
        authorizationUrl: google.authorizationUrl({
          state,
          nonce,
          codeChallenge: digest(googleVerifier),
        }),
        expiresIn: 600,
      };
    },
  );

  app.get(
    "/auth/google/callback",
    {
      onRequest: noCache,
      logLevel: "silent",
      schema: {
        tags: ["Auth"],
        summary:
          "Google redirect URI; trả mã một lần về app, không trả JWT qua URL",
        querystring: object(
          {
            state: { type: "string", maxLength: 256 },
            code: { type: "string", maxLength: 4096 },
            error: { type: "string", maxLength: 256 },
            scope: { type: "string", maxLength: 4096 },
            authuser: { type: "string", maxLength: 64 },
            prompt: { type: "string", maxLength: 256 },
            hd: { type: "string", maxLength: 256 },
            error_description: { type: "string", maxLength: 2048 },
            error_uri: { type: "string", maxLength: 2048 },
            iss: {
              type: "string",
              enum: ["https://accounts.google.com", "accounts.google.com"],
            },
          },
          ["state"],
        ),
        response: { 302: { type: "null" }, ...errors },
      },
    },
    async (request, reply) => {
      requireEnabled();
      const flow = await store.one(
        "UPDATE google_oauth_flows SET callback_used=1 WHERE state_digest=? AND callback_used=0 AND expires_at>? RETURNING *",
        digest(request.query.state),
        Date.now(),
      );
      if (!flow)
        fail(400, "Yêu cầu Google không hợp lệ, đã dùng hoặc đã hết hạn.");
      if (request.query.error || !request.query.code)
        return returnToApp(reply, flow.id, {
          error:
            request.query.error === "access_denied"
              ? "cancelled"
              : "google_failed",
        });
      let profile;
      try {
        profile = await google.exchange(
          request.query.code,
          flow.google_verifier,
        );
      } catch {
        return returnToApp(reply, flow.id, { error: "google_failed" });
      }
      if (
        !profile ||
        !same(profile.nonce, flow.nonce) ||
        profile.email_verified !== true ||
        typeof profile.sub !== "string" ||
        !profile.sub ||
        profile.sub.length > 255 ||
        typeof profile.email !== "string" ||
        profile.email.length > 254 ||
        !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(profile.email)
      ) {
        return returnToApp(reply, flow.id, { error: "invalid_identity" });
      }
      const email = profile.email.trim().toLowerCase(),
        ticket = random();
      // An unreachable random password allows Google users to set their own password
      // later through the existing mailbox OTP reset, without a shared default.
      const randomPassword = await hashPassword(random());
      try {
        const result = await store.transaction(async () => {
          const identity = await store.one(
            "SELECT user_id FROM google_identities WHERE subject=?",
            profile.sub,
          );
          let user;
          if (flow.link_user_id) {
            if (
              !(await store.one(
                "SELECT id FROM sessions WHERE id=? AND user_id=? AND expires_at>?",
                flow.link_session_id,
                flow.link_user_id,
                Date.now(),
              ))
            )
              return { error: "authorization_expired" };
            user = await store.one(
              "SELECT * FROM users WHERE id=?",
              flow.link_user_id,
            );
            if (!user?.active || !user.verified)
              return { error: "account_disabled" };
            if (user.email !== email) return { error: "email_mismatch" };
            if (identity && identity.user_id !== user.id)
              return { error: "already_linked" };
            if (!identity)
              await store.run(
                "INSERT INTO google_identities(subject,user_id) VALUES(?,?)",
                profile.sub,
                user.id,
              );
          } else if (identity) {
            user = await store.one(
              "SELECT * FROM users WHERE id=?",
              identity.user_id,
            );
          } else {
            if (await store.one("SELECT id FROM users WHERE email=?", email))
              return { error: "account_exists" };
            // Google is authoritative for Gmail and signed Workspace hd claims.
            // A third-party mailbox may have changed owners since Google verified it.
            // Require Motion mailbox OTP registration and explicit linking first.
            if (
              !email.endsWith("@gmail.com") &&
              !(typeof profile.hd === "string" && profile.hd.length > 0)
            ) {
              return { error: "email_verification_required" };
            }
            const userId = randomUUID();
            const name =
              (typeof profile.name === "string"
                ? profile.name.trim()
                : ""
              ).slice(0, 80) || email.split("@")[0];
            await store.run(
              "INSERT INTO users(id,email,name,password,role,verified,created_at) VALUES(?,?,?,?,'member',1,?)",
              userId,
              email,
              name,
              randomPassword,
              Date.now(),
            );
            await store.run(
              "INSERT INTO google_identities(subject,user_id) VALUES(?,?)",
              profile.sub,
              userId,
            );
            user = await store.one("SELECT * FROM users WHERE id=?", userId);
          }
          if (!user?.active || !user.verified)
            return { error: "account_disabled" };
          await store.run(
            "UPDATE google_oauth_flows SET user_id=?,ticket_digest=? WHERE id=?",
            user.id,
            digest(ticket),
            flow.id,
          );
          return {};
        });
        if (result.error)
          return returnToApp(reply, flow.id, { error: result.error });
      } catch {
        return returnToApp(reply, flow.id, { error: "google_failed" });
      }
      return returnToApp(reply, flow.id, { ticket });
    },
  );

  app.post(
    "/auth/google/exchange",
    {
      onRequest: noCache,
      schema: {
        tags: ["Auth"],
        summary:
          "Đổi ticket một lần + PKCE verifier thành phiên Motion; không dùng Google token làm JWT Motion",
        body: { $ref: "GoogleOAuthExchangeRequest#" },
        response: { 200: { $ref: "AuthSessionResponse#" }, ...errors },
      },
    },
    async (request) => {
      requireEnabled();
      const { flowId, ticket, codeVerifier } = request.body;
      const user = await store.transaction(async () => {
        const flow = await store.one(
          "SELECT * FROM google_oauth_flows WHERE id=? AND expires_at>? AND exchanged=0",
          flowId,
          Date.now(),
        );
        if (
          !flow ||
          !flow.user_id ||
          !same(flow.ticket_digest, digest(ticket)) ||
          !same(flow.app_challenge, digest(codeVerifier))
        )
          fail(400, "Phiên Google không hợp lệ, đã dùng hoặc đã hết hạn.");
        if (
          flow.link_user_id &&
          !(await store.one(
            "SELECT id FROM sessions WHERE id=? AND user_id=? AND expires_at>?",
            flow.link_session_id,
            flow.link_user_id,
            Date.now(),
          ))
        )
          fail(401, "Phiên liên kết đã hết hạn. Hãy đăng nhập lại.");
        const account = await store.one(
          "SELECT * FROM users WHERE id=?",
          flow.user_id,
        );
        if (!account?.active || !account.verified)
          fail(403, "Tài khoản đã bị khóa hoặc không còn hoạt động.");
        await store.run(
          "UPDATE google_oauth_flows SET exchanged=1,google_verifier=? WHERE id=?",
          "",
          flow.id,
        );
        return account;
      });
      return sessionFor(user);
    },
  );
}
