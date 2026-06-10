/* HMAC-signed cookie sessions + one-shot flash messages.

   The session payload is {uid, csrf} — the same shape Flask kept for us.
   Flash messages ride in their own short-lived cookie (display-only text,
   always HTML-escaped at render time). */
import { deleteCookie, getCookie, setCookie } from "hono/cookie";

import { fromBase64Url, hmacSign, randomHex, timingSafeEqualStr, toBase64Url } from "./crypto.js";

const SESSION_COOKIE = "session";
const FLASH_COOKIE = "flash";
const decoder = new TextDecoder();

function cookieOptions(c) {
  return {
    path: "/",
    httpOnly: true,
    sameSite: "Lax",
    secure: c.env.DEV !== "1", // workers.dev is always HTTPS; local dev is HTTP
  };
}

async function encodeSession(secret, payload) {
  const body = toBase64Url(new TextEncoder().encode(JSON.stringify(payload)));
  const sig = toBase64Url(await hmacSign(secret, body));
  return `${body}.${sig}`;
}

async function decodeSession(secret, cookie) {
  if (!cookie || !cookie.includes(".")) return null;
  const [body, sig] = cookie.split(".");
  const expected = toBase64Url(await hmacSign(secret, body));
  if (!timingSafeEqualStr(sig, expected)) return null;
  try {
    return JSON.parse(decoder.decode(fromBase64Url(body)));
  } catch {
    return null;
  }
}

export function newSession() {
  return { uid: null, csrf: randomHex(32), _dirty: true };
}

/* Loads (or creates) the session, exposes it as c.var.sess, and writes the
   cookie back after the handler if anything changed. */
export function sessionMiddleware() {
  return async (c, next) => {
    const secret = c.env.SECRET_KEY || "dev";
    const parsed = await decodeSession(secret, getCookie(c, SESSION_COOKIE));
    const sess = parsed && typeof parsed.csrf === "string"
      ? { uid: parsed.uid ?? null, csrf: parsed.csrf, _dirty: false }
      : newSession();
    c.set("sess", sess);

    await next();

    if (sess._dirty) {
      const value = await encodeSession(secret, { uid: sess.uid, csrf: sess.csrf });
      setCookie(c, SESSION_COOKIE, value, cookieOptions(c));
    }
    const outgoing = c.get("flashOut");
    if (outgoing && outgoing.length) {
      setCookie(c, FLASH_COOKIE, toBase64Url(new TextEncoder().encode(JSON.stringify(outgoing))),
        cookieOptions(c));
    }
  };
}

export function logIn(c, userId) {
  const sess = c.get("sess");
  sess.uid = userId;
  sess.csrf = randomHex(32); // fresh token on privilege change
  sess._dirty = true;
}

export function logOut(c) {
  const sess = c.get("sess");
  sess.uid = null;
  sess.csrf = randomHex(32);
  sess._dirty = true;
}

export function flash(c, category, message) {
  const list = c.get("flashOut") || [];
  c.set("flashOut", [...list, [category, message]]);
}

/* Read-and-clear, called when rendering a page. */
export function takeFlashes(c) {
  const raw = getCookie(c, FLASH_COOKIE);
  if (!raw) return [];
  deleteCookie(c, FLASH_COOKIE, { path: "/" });
  try {
    const parsed = JSON.parse(decoder.decode(fromBase64Url(raw)));
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}
