import {
  randomBytes,
  randomInt,
  scrypt as scryptCallback,
  timingSafeEqual,
  createHmac,
} from "node:crypto";
import { promisify } from "node:util";
const scrypt = promisify(scryptCallback);

export async function hashPassword(password) {
  const salt = randomBytes(16).toString("hex");
  const hash = await scrypt(password, salt, 64, { N: 16384, r: 8, p: 1 });
  return `scrypt:${salt}:${hash.toString("hex")}`;
}
export async function verifyPassword(password, encoded) {
  const [, salt, hex] = encoded.split(":");
  const hash = await scrypt(password, salt, 64, { N: 16384, r: 8, p: 1 });
  return timingSafeEqual(hash, Buffer.from(hex, "hex"));
}
export const newOtp = () => randomInt(0, 1_000_000).toString().padStart(6, "0");
export const otpDigest = (secret, id, code) =>
  createHmac("sha256", secret).update(`${id}:${code}`).digest("hex");
export const validOtp = (secret, challenge, code) =>
  timingSafeEqual(
    Buffer.from(challenge.digest, "hex"),
    Buffer.from(otpDigest(secret, challenge.id, code), "hex"),
  );

export function configFromEnv() {
  const config = {
    databasePath: process.env.DATABASE_PATH || "./data/motion.sqlite",
    databaseUrl: process.env.DATABASE_URL,
    jwtSecret: process.env.JWT_SECRET || "",
    otpSecret: process.env.OTP_SECRET || "",
    publicUrl:
      process.env.PUBLIC_URL ||
      process.env.RENDER_EXTERNAL_URL ||
      "https://motion-api.vihx.online",
    mailProvider: process.env.MAIL_PROVIDER || "smtp",
    resendApiKey: process.env.RESEND_API_KEY,
    smtp: {
      host: process.env.SMTP_HOST,
      port: Number(process.env.SMTP_PORT || 587),
      secure: process.env.SMTP_PORT === "465",
      requireTLS: process.env.SMTP_PORT !== "465",
      auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
    },
    mailFrom: process.env.MAIL_FROM || process.env.SMTP_FROM,
  };
  for (const key of ["jwtSecret", "otpSecret"]) {
    if (config[key].length < 32)
      throw new Error(`${key} must contain at least 32 random characters`);
  }
  if (config.jwtSecret === config.otpSecret)
    throw new Error("JWT_SECRET and OTP_SECRET must differ");
  if (!/^https:\/\//.test(config.publicUrl))
    throw new Error("PUBLIC_URL must use HTTPS");
  if (process.env.RENDER && !config.databaseUrl)
    throw new Error(
      "Render requires DATABASE_URL; ephemeral SQLite is disabled",
    );
  if (config.databaseUrl && !/^postgres(ql)?:\/\//.test(config.databaseUrl))
    throw new Error("DATABASE_URL must be a PostgreSQL connection string");
  if (!["smtp", "resend"].includes(config.mailProvider))
    throw new Error("MAIL_PROVIDER must be smtp or resend");
  if (
    config.mailProvider === "resend" &&
    (!config.resendApiKey || !config.mailFrom)
  )
    throw new Error("Configure RESEND_API_KEY and MAIL_FROM");
  if (
    config.mailProvider === "smtp" &&
    (!config.smtp.host ||
      !config.smtp.auth.user ||
      !config.smtp.auth.pass ||
      !config.mailFrom)
  ) {
    throw new Error(
      "Configure SMTP_HOST/USER/PASS/FROM before starting the API",
    );
  }
  return config;
}
