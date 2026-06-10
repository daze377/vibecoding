/* JSON APIs: comments and reactions (same contract as the Flask version). */
import { Hono } from "hono";

import { requireUser } from "./auth.js";
import * as db from "./db.js";

const MAX_COMMENT_LENGTH = 2_000;
const ALLOWED_KINDS = new Set(["like", "dislike"]);

export const api = new Hono();

async function loadPost(c) {
  const id = Number(c.req.param("id"));
  if (!Number.isInteger(id) || id < 1) return null;
  return db.getPost(c.env.DB, id);
}

api.post("/api/post/:id/comment", async (c) => {
  const guard = requireUser(c);
  if (guard) return guard;
  const post = await loadPost(c);
  if (!post) return c.json({ ok: false, error: "Post not found." }, 404);

  const payload = await c.req.json().catch(() => ({}));
  const raw = payload.body ?? "";
  if (typeof raw !== "string") {
    return c.json({ ok: false, error: "Comment must be text." }, 400);
  }
  const body = raw.trim();
  if (!body) {
    return c.json({ ok: false, error: "Comment cannot be empty." }, 400);
  }
  if (body.length > MAX_COMMENT_LENGTH) {
    return c.json(
      { ok: false, error: `Comment must be at most ${MAX_COMMENT_LENGTH} characters.` }, 400,
    );
  }

  const comment = await db.addComment(c.env.DB, post.id, c.get("user").id, body);
  return c.json({ ok: true, comment }, 201);
});

api.post("/api/post/:id/react", async (c) => {
  const guard = requireUser(c);
  if (guard) return guard;
  const post = await loadPost(c);
  if (!post) return c.json({ ok: false, error: "Post not found." }, 404);

  const payload = await c.req.json().catch(() => ({}));
  if (!ALLOWED_KINDS.has(payload.kind)) {
    return c.json({ ok: false, error: "Reaction must be 'like' or 'dislike'." }, 400);
  }

  const reaction = await db.setReaction(c.env.DB, post.id, c.get("user").id, payload.kind);
  const counts = await db.countReactions(c.env.DB, post.id);
  return c.json({ ok: true, reaction, counts });
});
