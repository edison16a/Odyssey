// Sign in with a one-time code sent to your email (Convex Auth).
//
// The app calls the `auth:signIn` action twice: first with
// { provider: "email-otp", params: { email } } to send a code, then with
// { provider: "email-otp", params: { email, code } } to get an access token
// and refresh token. Refreshing is `auth:signIn` with { refreshToken }.
//
// Codes go out through Resend when AUTH_RESEND_KEY is set. Without it (local
// development) the code is printed to the Convex logs instead.

import { convexAuth } from "@convex-dev/auth/server";
import { Email } from "@convex-dev/auth/providers/Email";

const CODE_LENGTH = 6;

function randomCode(): string {
  const bytes = new Uint32Array(CODE_LENGTH);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => (b % 10).toString()).join("");
}

const EmailOTP = Email({
  id: "email-otp",
  maxAge: 60 * 15,
  async generateVerificationToken() {
    return randomCode();
  },
  async sendVerificationRequest({ identifier: email, token }) {
    const key = process.env.AUTH_RESEND_KEY;
    if (!key) {
      console.log(`[odyssey auth] sign-in code for ${email}: ${token} (set AUTH_RESEND_KEY to email it)`);
      return;
    }
    const from = process.env.AUTH_EMAIL_FROM ?? "Odyssey <onboarding@resend.dev>";
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from,
        to: [email],
        subject: `${token} is your Odyssey code`,
        text: `Your Odyssey sign-in code is ${token}. It expires in 15 minutes.\n\nGo explore. Get rewarded.`,
      }),
    });
    if (!res.ok) {
      throw new Error(`Could not send the sign-in email: ${res.status} ${await res.text()}`);
    }
  },
});

export const { auth, signIn, signOut, store, isAuthenticated } = convexAuth({
  providers: [EmailOTP],
});
