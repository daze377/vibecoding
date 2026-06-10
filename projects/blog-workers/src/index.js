/* Blog on Cloudflare Workers + D1 — entry point wiring all middleware/routes.
   A port of the Flask version in projects/blog (see task-11.md there). */
import { Hono } from "hono";

import { api } from "./api.js";
import { auth } from "./auth.js";
import { csrfMiddleware } from "./csrf.js";
import { posts } from "./posts.js";
import { search } from "./search.js";
import { sessionMiddleware } from "./session.js";
import { getUserById } from "./db.js";

const app = new Hono();

/* Baseline browser protections on every Worker response. */
app.use("*", async (c, next) => {
  await next();
  c.res.headers.set("Content-Security-Policy", "default-src 'self'");
  c.res.headers.set("X-Content-Type-Options", "nosniff");
  c.res.headers.set("X-Frame-Options", "DENY");
});

app.use("*", sessionMiddleware());

/* Make the logged-in user available on every request. */
app.use("*", async (c, next) => {
  const sess = c.get("sess");
  c.set("user", sess.uid ? await getUserById(c.env.DB, sess.uid) : null);
  await next();
});

app.use("*", csrfMiddleware());

app.route("/", auth);
app.route("/", posts);
app.route("/", api);
app.route("/", search);

app.notFound((c) => c.text("404 Not Found", 404));
app.onError((err, c) => {
  console.error("unhandled error:", err); // detail stays in logs, not the page
  return c.text("500 Internal Server Error", 500);
});

export default app;
