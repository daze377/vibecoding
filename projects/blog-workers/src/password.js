/* Password hashing on Web Crypto: HMAC pepper (server secret) + PBKDF2.

   Workers has no scrypt/argon2, and the free plan caps CPU per request, so
   iterations are modest. The HMAC pepper means a leaked database alone is
   not enough to crack passwords offline. */
import { fromBase64Url, hmacSign, toBase64Url } from "./crypto.js";

const ITERATIONS = 100_000;
const KEY_BYTES = 32;

async function derive(password, secret, salt, iterations) {
  const peppered = await hmacSign(secret, password);
  const key = await crypto.subtle.importKey("raw", peppered, "PBKDF2", false, ["deriveBits"]);
  return crypto.subtle.deriveBits(
    { name: "PBKDF2", hash: "SHA-256", salt, iterations },
    key,
    KEY_BYTES * 8,
  );
}

export async function hashPassword(password, secret) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const bits = await derive(password, secret, salt, ITERATIONS);
  return `v1$${ITERATIONS}$${toBase64Url(salt)}$${toBase64Url(bits)}`;
}

export async function verifyPassword(password, stored, secret) {
  const parts = (stored || "").split("$");
  if (parts.length !== 4 || parts[0] !== "v1") return false;
  const iterations = Number(parts[1]);
  if (!Number.isInteger(iterations) || iterations < 1) return false;
  const salt = fromBase64Url(parts[2]);
  const expected = fromBase64Url(parts[3]);
  const actual = new Uint8Array(await derive(password, secret, salt, iterations));
  if (actual.byteLength !== expected.byteLength) return false;
  return crypto.subtle.timingSafeEqual(actual, expected);
}
