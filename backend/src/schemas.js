const text = { type: "string" };
const timestamp = {
  type: "integer",
  description: "Unix timestamp (milliseconds, UTC)",
};
const uuid = { type: "string", format: "uuid" };
const object = (properties) => ({
  type: "object",
  additionalProperties: false,
  required: Object.keys(properties),
  properties,
});
export const userSchema = object({
  id: uuid,
  email: { type: "string", format: "email" },
  name: text,
  role: { type: "string", enum: ["admin", "staff", "member"] },
  verified: { type: "boolean" },
  active: { type: "boolean" },
  assignedStaffId: { type: "string", nullable: true },
  createdAt: timestamp,
});
const contact = object({
  id: uuid,
  ownerId: uuid,
  name: text,
  phone: text,
  relationship: text,
  createdAt: timestamp,
  updatedAt: timestamp,
});
const checkin = object({
  id: uuid,
  ownerId: uuid,
  title: text,
  dueAt: timestamp,
  status: {
    type: "string",
    enum: ["pending", "safe", "needs_help", "resolved"],
  },
  note: text,
  overdue: { type: "boolean" },
  createdAt: timestamp,
  updatedAt: timestamp,
});
const message = object({ message: text });
const challenge = object({
  challengeId: uuid,
  expiresIn: { type: "integer", example: 300 },
  message: text,
});
const session = object({
  accessToken: {
    type: "string",
    description:
      "Bearer token; expires after 12 hours; revoked by logout/reset/lock/role change",
  },
  expiresIn: { type: "integer", example: 2592000 },
  user: { $ref: "User#" },
});
const list = (item) => object({ items: { type: "array", items: item } });

const ref = (name) => ({ $ref: `${name}#` });
export function registerModels(app) {
  const models = {
    User: userSchema,
    EmergencyContact: contact,
    SafetyCheckIn: checkin,
    MessageResponse: message,
    OtpChallengeResponse: challenge,
    AuthSessionResponse: session,
    HealthResponse: object({ status: text, service: text }),
    UserListResponse: list(ref("User")),
    ContactListResponse: list(ref("EmergencyContact")),
    CheckInListResponse: list(ref("SafetyCheckIn")),
  };
  for (const [name, schema] of Object.entries(models)) {
    app.addSchema({ $id: name, title: name, ...schema });
  }
}

const requestNames = {
  "POST /auth/register": "RegisterRequest",
  "POST /auth/verify-email": "VerifyEmailRequest",
  "POST /auth/login": "LoginRequest",
  "POST /auth/login/verify": "VerifyLoginOtpRequest",
  "POST /auth/forgot-password": "ForgotPasswordRequest",
  "POST /auth/reset-password": "ResetPasswordRequest",
  "PATCH /me": "UpdateProfileRequest",
  "DELETE /me": "DeleteAccountRequest",
  "POST /users": "CreateUserRequest",
  "PATCH /users/:id": "UpdateUserRequest",
  "POST /contacts": "CreateContactRequest",
  "PATCH /contacts/:id": "UpdateContactRequest",
  "POST /checkins": "CreateCheckInRequest",
  "PATCH /checkins/:id": "UpdateCheckInRequest",
};
export function requestModel(app, method, url, schema) {
  if (!schema.body) return schema;
  const name = requestNames[`${method} ${url}`];
  if (!name) throw new Error(`Missing request model name: ${method} ${url}`);
  const model = structuredClone(schema.body);
  // Keep original validators, while documenting credential inputs as write-only.
  if (model.properties.password) {
    model.properties.password.format = "password";
    model.properties.password.writeOnly = true;
  }
  app.addSchema({ $id: name, title: name, ...model });
  return { ...schema, body: ref(name) };
}

export function responses(method, url) {
  let success = ref("MessageResponse");
  if (url === "/health") success = ref("HealthResponse");
  else if (
    ["/auth/register", "/auth/login", "/auth/forgot-password"].includes(url)
  )
    success = ref("OtpChallengeResponse");
  else if (url === "/auth/login/verify") success = ref("AuthSessionResponse");
  else if (method !== "DELETE") {
    if (url === "/me" || url.startsWith("/users"))
      success =
        url === "/users" && method === "GET"
          ? ref("UserListResponse")
          : ref("User");
    if (url.startsWith("/contacts"))
      success =
        url === "/contacts" && method === "GET"
          ? ref("ContactListResponse")
          : ref("EmergencyContact");
    if (url.startsWith("/checkins"))
      success =
        url === "/checkins" && method === "GET"
          ? ref("CheckInListResponse")
          : ref("SafetyCheckIn");
  }
  return {
    200: { description: "Thành công", ...success },
    400: {
      description: "Dữ liệu không hợp lệ hoặc OTP hết hạn/sai/đã dùng",
      ...ref("MessageResponse"),
    },
    401: {
      description:
        "Chưa đăng nhập, phiên hết hạn/bị thu hồi hoặc sai thông tin đăng nhập",
      ...ref("MessageResponse"),
    },
    403: { description: "Không đủ quyền truy cập", ...ref("MessageResponse") },
    404: {
      description: "Không tìm thấy hoặc không có quyền sở hữu bản ghi",
      ...ref("MessageResponse"),
    },
    409: {
      description: "Dữ liệu trùng lặp/xung đột hoặc quản trị viên cuối cùng",
      ...ref("MessageResponse"),
    },
    429: {
      description: "Vượt giới hạn yêu cầu; đợi trước khi thử lại",
      ...ref("MessageResponse"),
    },
    500: { description: "Lỗi máy chủ", ...ref("MessageResponse") },
    503: {
      description: "Dịch vụ gửi email chưa khả dụng",
      ...ref("MessageResponse"),
    },
  };
}
