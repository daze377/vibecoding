/* CSRF protection: every state-changing request must echo the session token.
   Forms send a hidden csrf_token field; the JSON API sends X-CSRF-Token. */
import { timingSafeEqualStr } from "./crypto.js";

const PROTECTED = new Set(["POST", "PUT", "PATCH", "DELETE"]);

export function csrfMiddleware() {
  return async (c, next) => {
    if (!PROTECTED.has(c.req.method)) return next();

    let token = c.req.header("X-CSRF-Token");
    if (!token) {
      const type = c.req.header("Content-Type") || "";
      if (type.includes("form")) {
        const body = await c.req.parseBody(); // cached — handlers reuse it
        if (typeof body.csrf_token === "string") token = body.csrf_token;
      }
    }

    const sess = c.get("sess");
    if (!token || !sess.csrf || !timingSafeEqualStr(token, sess.csrf)) {
      if (c.req.path.startsWith("/api/")) {
        return c.json({ ok: false, error: "Invalid or missing CSRF token." }, 400);
      }
      return c.text("Bad Request: invalid or missing CSRF token.", 400);
    }
    return next();
  };
}
