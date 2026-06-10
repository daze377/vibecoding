/* Home list, post detail, and author-only create/edit/delete. */
import { Hono } from "hono";

import { render, requireUser } from "./auth.js";
import * as db from "./db.js";
import { editPage, indexPage, postPage, postScripts } from "./html.js";
import { layout } from "./html.js";
import { flash, takeFlashes } from "./session.js";

const MAX_TITLE_LENGTH = 200;
const MAX_BODY_LENGTH = 20_000;

export const posts = new Hono();

function parseId(c) {
  const id = Number(c.req.param("id"));
  return Number.isInteger(id) && id > 0 ? id : null;
}

function validatePostForm(title, body) {
  const errors = [];
  if (!title) errors.push("Title cannot be empty.");
  else if (title.length > MAX_TITLE_LENGTH) {
    errors.push(`Title must be at most ${MAX_TITLE_LENGTH} characters.`);
  }
  if (!body) errors.push("Body cannot be empty.");
  else if (body.length > MAX_BODY_LENGTH) {
    errors.push(`Body must be at most ${MAX_BODY_LENGTH} characters.`);
  }
  return errors;
}

posts.get("/", async (c) =>
  render(c, "Home", indexPage(await db.listPosts(c.env.DB))),
);

posts.get("/post/:id", async (c) => {
  const id = parseId(c);
  const post = id && (await db.getPost(c.env.DB, id));
  if (!post) return c.text("404 Not Found", 404);

  const user = c.get("user");
  const [comments, counts, myReaction] = await Promise.all([
    db.listComments(c.env.DB, id),
    db.countReactions(c.env.DB, id),
    user ? db.getReaction(c.env.DB, id, user.id) : null,
  ]);
  return c.html(
    layout({
      title: post.title,
      user,
      csrf: c.get("sess").csrf,
      flashes: takeFlashes(c),
      content: postPage({ post, comments, counts, myReaction, user, csrf: c.get("sess").csrf }),
      scripts: postScripts,
    }),
  );
});

posts.get("/new", (c) => {
  const guard = requireUser(c);
  if (guard) return guard;
  return render(c, "New post", editPage({ post: null, csrf: c.get("sess").csrf }));
});

posts.post("/new", async (c) => {
  const guard = requireUser(c);
  if (guard) return guard;

  const form = await c.req.parseBody();
  const title = String(form.title ?? "").trim();
  const body = String(form.body ?? "").trim();
  const errors = validatePostForm(title, body);
  if (errors.length) {
    for (const message of errors) flash(c, "error", message);
    return render(
      c, "New post",
      editPage({ post: null, csrf: c.get("sess").csrf, values: { title, body } }), 400,
    );
  }

  const postId = await db.createPost(c.env.DB, c.get("user").id, title, body);
  flash(c, "success", "Post published.");
  return c.redirect(`/post/${postId}`);
});

/* Loads the post and enforces author-only access; returns a Response on failure. */
async function loadOwnPost(c) {
  const id = parseId(c);
  const post = id && (await db.getPost(c.env.DB, id));
  if (!post) return { error: c.text("404 Not Found", 404) };
  const user = c.get("user");
  if (!user || user.id !== post.author_id) {
    return { error: c.text("403 Forbidden", 403) };
  }
  return { post };
}

posts.get("/edit/:id", async (c) => {
  const guard = requireUser(c);
  if (guard) return guard;
  const { post, error } = await loadOwnPost(c);
  if (error) return error;
  return render(c, "Edit post", editPage({ post, csrf: c.get("sess").csrf }));
});

posts.post("/edit/:id", async (c) => {
  const guard = requireUser(c);
  if (guard) return guard;
  const { post, error } = await loadOwnPost(c);
  if (error) return error;

  const form = await c.req.parseBody();
  const title = String(form.title ?? "").trim();
  const body = String(form.body ?? "").trim();
  const errors = validatePostForm(title, body);
  if (errors.length) {
    for (const message of errors) flash(c, "error", message);
    return render(
      c, "Edit post",
      editPage({ post, csrf: c.get("sess").csrf, values: { title, body } }), 400,
    );
  }

  await db.updatePost(c.env.DB, post.id, title, body);
  flash(c, "success", "Post updated.");
  return c.redirect(`/post/${post.id}`);
});

posts.post("/delete/:id", async (c) => {
  const guard = requireUser(c);
  if (guard) return guard;
  const { post, error } = await loadOwnPost(c);
  if (error) return error;

  await db.deletePost(c.env.DB, post.id);
  flash(c, "success", "Post deleted.");
  return c.redirect("/");
});
