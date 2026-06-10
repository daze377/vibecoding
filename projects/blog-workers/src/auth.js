/* Sign up, log in, log out — same rules and messages as the Flask version. */
import { Hono } from "hono";

import * as db from "./db.js";
import { layout, loginPage, signupPage } from "./html.js";
import { flash, logIn, logOut, takeFlashes } from "./session.js";
import { hashPassword, verifyPassword } from "./password.js";

const USERNAME_RE = /^[A-Za-z0-9_]{3,30}$/;
const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const MIN_PASSWORD_LENGTH = 8;

export const auth = new Hono();

export function validateSignup(username, email, password) {
  const errors = [];
  if (!USERNAME_RE.test(username)) {
    errors.push("Username must be 3-30 letters, digits, or underscores.");
  }
  if (!EMAIL_RE.test(email)) {
    errors.push("Please enter a valid email address.");
  }
  if (password.length < MIN_PASSWORD_LENGTH) {
    errors.push(`Password must be at least ${MIN_PASSWORD_LENGTH} characters.`);
  }
  return errors;
}

/* Only follow same-site relative ?next= targets (no open redirects).
   Backslashes rejected too: browsers treat /\evil.com like //evil.com. */
export function safeNextUrl(nextUrl) {
  const isLocalPath =
    nextUrl.startsWith("/") && !nextUrl.startsWith("//") && !nextUrl.includes("\\");
  return isLocalPath ? nextUrl : "/";
}

function render(c, title, content, status = 200) {
  return c.html(
    layout({
      title,
      user: c.get("user"),
      csrf: c.get("sess").csrf,
      flashes: takeFlashes(c),
      content,
    }),
    status,
  );
}

auth.get("/signup", (c) =>
  render(c, "Sign up", signupPage({ csrf: c.get("sess").csrf })),
);

auth.post("/signup", async (c) => {
  const form = await c.req.parseBody();
  const username = String(form.username ?? "").trim();
  const email = String(form.email ?? "").trim().toLowerCase();
  const password = String(form.password ?? "");

  const errors = validateSignup(username, email, password);
  if (!errors.length && (await db.getUserByUsername(c.env.DB, username))) {
    errors.push("That username is already taken.");
  }
  if (!errors.length && (await db.getUserByEmail(c.env.DB, email))) {
    errors.push("That email is already registered.");
  }
  if (errors.length) {
    for (const message of errors) flash(c, "error", message);
    return render(c, "Sign up", signupPage({ csrf: c.get("sess").csrf, username, email }), 400);
  }

  const secret = c.env.SECRET_KEY || "dev";
  try {
    await db.createUser(c.env.DB, username, email, await hashPassword(password, secret));
  } catch (err) {
    if (String(err).includes("UNIQUE")) {
      // two signups raced past the checks above — the UNIQUE constraint wins
      flash(c, "error", "That username or email is already taken.");
      return render(c, "Sign up", signupPage({ csrf: c.get("sess").csrf, username, email }), 400);
    }
    throw err;
  }
  flash(c, "success", "Account created — please log in.");
  return c.redirect("/login");
});

auth.get("/login", (c) =>
  render(c, "Log in", loginPage({ csrf: c.get("sess").csrf, next: c.req.query("next") || "" })),
);

auth.post("/login", async (c) => {
  const form = await c.req.parseBody();
  const username = String(form.username ?? "").trim();
  const password = String(form.password ?? "");
  const next = c.req.query("next") || "";

  const user = await db.getUserByUsername(c.env.DB, username);
  const secret = c.env.SECRET_KEY || "dev";
  const ok = user && (await verifyPassword(password, user.password_hash, secret));
  if (!ok) {
    flash(c, "error", "Wrong username or password.");
    return render(c, "Log in", loginPage({ csrf: c.get("sess").csrf, next, username }), 400);
  }

  logIn(c, user.id);
  flash(c, "success", `Welcome back, ${user.username}!`);
  return c.redirect(safeNextUrl(next));
});

auth.post("/logout", (c) => {
  logOut(c);
  flash(c, "success", "You have been logged out.");
  return c.redirect("/");
});

/* Guard for pages (redirect) and APIs (JSON 401). */
export function requireUser(c) {
  if (c.get("user")) return null;
  if (c.req.path.startsWith("/api/")) {
    return c.json({ ok: false, error: "Please log in first." }, 401);
  }
  return c.redirect(`/login?next=${encodeURIComponent(c.req.path)}`);
}

export { render };
