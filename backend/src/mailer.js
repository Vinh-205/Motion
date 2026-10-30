import nodemailer from "nodemailer";

export function createMailer(config, fetcher = fetch) {
  if (config.mailProvider === "resend") {
    return {
      async sendMail(mail) {
        const response = await fetcher("https://api.resend.com/emails", {
          method: "POST",
          signal: AbortSignal.timeout(15_000),
          headers: {
            Authorization: `Bearer ${config.resendApiKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: mail.from,
            to: [mail.to],
            subject: mail.subject,
            text: mail.text,
          }),
        });
        if (!response.ok)
          throw new Error(
            `Email provider rejected request (${response.status})`,
          );
        return { messageId: (await response.json()).id };
      },
    };
  }
  return nodemailer.createTransport({
    ...config.smtp,
    connectionTimeout: 10_000,
    greetingTimeout: 10_000,
    socketTimeout: 20_000,
    disableFileAccess: true,
    disableUrlAccess: true,
  });
}
