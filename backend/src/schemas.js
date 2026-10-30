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
  expiresIn: { type: "integer", example: 43200 },
  user: userSchema,
});
const list = (item) => object({ items: { type: "array", items: item } });

export function responses(method, url) {
  let success = message;
  if (url === "/health") success = object({ status: text, service: text });
  else if (
    ["/auth/register", "/auth/login", "/auth/forgot-password"].includes(url)
  )
    success = challenge;
  else if (url === "/auth/login/verify") success = session;
  else if (method !== "DELETE") {
    if (url === "/me" || url.startsWith("/users"))
      success =
        url === "/users" && method === "GET" ? list(userSchema) : userSchema;
    if (url.startsWith("/contacts"))
      success =
        url === "/contacts" && method === "GET" ? list(contact) : contact;
    if (url.startsWith("/checkins"))
      success =
        url === "/checkins" && method === "GET" ? list(checkin) : checkin;
  }
  return {
    200: { description: "Thành công", ...success },
    400: {
      description: "Dữ liệu không hợp lệ hoặc OTP hết hạn/sai/đã dùng",
      ...message,
    },
    401: {
      description:
        "Chưa đăng nhập, phiên hết hạn/bị thu hồi hoặc sai thông tin đăng nhập",
      ...message,
    },
    403: { description: "Không đủ quyền truy cập", ...message },
    404: {
      description: "Không tìm thấy hoặc không có quyền sở hữu bản ghi",
      ...message,
    },
    409: {
      description: "Dữ liệu trùng lặp/xung đột hoặc quản trị viên cuối cùng",
      ...message,
    },
    429: {
      description: "Vượt giới hạn yêu cầu; đợi trước khi thử lại",
      ...message,
    },
    500: { description: "Lỗi máy chủ", ...message },
    503: { description: "Dịch vụ gửi email chưa khả dụng", ...message },
  };
}
