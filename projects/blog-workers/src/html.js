/* Server-rendered pages — a faithful port of the Jinja templates.
   Every piece of user content goes through esc(). */

export function esc(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

export const day = (timestamp) => (timestamp || "").slice(0, 10);

/* Word-boundary preview with an ellipsis, like Jinja's truncate(150). */
export function truncate(text, length = 150) {
  if (text.length <= length) return text;
  const cut = text.slice(0, length);
  const lastSpace = cut.lastIndexOf(" ");
  return (lastSpace > 0 ? cut.slice(0, lastSpace) : cut) + "...";
}

export function layout({ title, user, csrf, flashes = [], content, scripts = "" }) {
  const flashHtml = flashes
    .map(([cat, msg]) => `<p class="flash flash-${esc(cat)}">${esc(msg)}</p>`)
    .join("\n");
  const navUser = user
    ? `<a href="/new">New post</a>
       <span class="nav-user">${esc(user.username)}</span>
       <form method="post" action="/logout">
         <input type="hidden" name="csrf_token" value="${esc(csrf)}">
         <button type="submit" class="button-link">Log out</button>
       </form>`
    : `<a href="/login">Log in</a>
       <a href="/signup">Sign up</a>`;
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${esc(title)} · My Blog</title>
  <meta name="csrf-token" content="${esc(csrf)}">
  <link rel="stylesheet" href="/static/style.css">
  <script src="/static/theme.js"></script>
</head>
<body>
  <header class="site-header">
    <nav class="nav">
      <a class="brand" href="/">My Blog</a>
      <form class="search-form" action="/search" method="get" role="search">
        <input type="search" name="q" placeholder="Search posts…" maxlength="100" aria-label="Search posts">
      </form>
      <div class="nav-links">
        ${navUser}
        <button id="theme-toggle" type="button" class="button-link" aria-label="Switch theme">🌙</button>
      </div>
    </nav>
  </header>
  <main class="container">
    ${flashHtml}
    ${content}
  </main>
  ${scripts}
</body>
</html>`;
}

export function postListHtml(posts) {
  if (!posts.length) return `<p class="empty">No posts yet.</p>`;
  const items = posts
    .map(
      (p) => `<li class="post-card">
        <h2><a href="/post/${p.id}">${esc(p.title)}</a></h2>
        <p class="post-meta">by ${esc(p.author)} · ${esc(day(p.created_at))}</p>
        <p class="post-preview">${esc(truncate(p.body))}</p>
      </li>`,
    )
    .join("\n");
  return `<ul class="post-list">${items}</ul>`;
}

export const indexPage = (posts) =>
  `<h1>Latest posts</h1>\n${postListHtml(posts)}`;

export function postPage({ post, comments, counts, myReaction, user, csrf }) {
  const edited = post.updated_at ? ` · edited ${esc(day(post.updated_at))}` : "";
  const authorActions =
    user && user.id === post.author_id
      ? `<div class="post-actions">
           <a class="button secondary" href="/edit/${post.id}">Edit</a>
           <form method="post" action="/delete/${post.id}" data-confirm="Delete this post?">
             <input type="hidden" name="csrf_token" value="${esc(csrf)}">
             <button type="submit" class="danger">Delete</button>
           </form>
         </div>`
      : "";
  const commentItems = comments.length
    ? comments
        .map(
          (cm) => `<div class="comment">
            <p class="comment-meta">${esc(cm.author)} · ${esc(day(cm.created_at))}</p>
            <p class="comment-text">${esc(cm.body)}</p>
          </div>`,
        )
        .join("\n")
    : `<p class="empty">No comments yet.</p>`;
  const commentForm = user
    ? `<noscript><p class="empty">Adding comments and reactions needs JavaScript enabled.</p></noscript>
       <form id="comment-form" class="form" data-url="/api/post/${post.id}/comment">
         <label for="comment-body">Add a comment</label>
         <textarea id="comment-body" rows="3" required maxlength="2000"></textarea>
         <p id="comment-error" class="form-error" hidden></p>
         <button type="submit">Comment</button>
       </form>`
    : `<p><a href="/login?next=/post/${post.id}">Log in</a> to comment.</p>`;
  return `<article class="post-full">
    <h1>${esc(post.title)}</h1>
    <p class="post-meta">by ${esc(post.author)} · ${esc(day(post.created_at))}${edited}</p>
    <div class="post-body">${esc(post.body)}</div>
    <div class="reactions" data-url="/api/post/${post.id}/react">
      <button type="button" data-react="like" class="react${myReaction === "like" ? " active" : ""}">
        👍 <span data-count="like">${counts.like}</span>
      </button>
      <button type="button" data-react="dislike" class="react${myReaction === "dislike" ? " active" : ""}">
        👎 <span data-count="dislike">${counts.dislike}</span>
      </button>
    </div>
    ${authorActions}
  </article>
  <section class="comments">
    <h2>Comments (${comments.length})</h2>
    ${commentItems}
    ${commentForm}
  </section>`;
}

export const postScripts = `<script src="/static/post.js" defer></script>`;

export function editPage({ post, csrf, values = {} }) {
  const heading = post ? "Edit post" : "New post";
  const title = values.title ?? (post ? post.title : "");
  const body = values.body ?? (post ? post.body : "");
  const cancel = post ? `/post/${post.id}` : "/";
  return `<h1>${heading}</h1>
  <form method="post" class="form">
    <input type="hidden" name="csrf_token" value="${esc(csrf)}">
    <label for="title">Title</label>
    <input id="title" name="title" required maxlength="200" value="${esc(title)}">
    <label for="body">Body</label>
    <textarea id="body" name="body" rows="12" required>${esc(body)}</textarea>
    <div class="post-actions">
      <button type="submit">Save</button>
      <a class="button secondary" href="${cancel}">Cancel</a>
    </div>
  </form>`;
}

export function loginPage({ csrf, next = "", username = "" }) {
  const action = next ? `/login?next=${encodeURIComponent(next)}` : "/login";
  return `<h1>Log in</h1>
  <form method="post" class="form" action="${esc(action)}">
    <input type="hidden" name="csrf_token" value="${esc(csrf)}">
    <label for="username">Username</label>
    <input id="username" name="username" required maxlength="30" value="${esc(username)}">
    <label for="password">Password</label>
    <input id="password" name="password" type="password" required>
    <button type="submit">Log in</button>
  </form>
  <p>No account yet? <a href="/signup">Sign up</a>.</p>`;
}

export function signupPage({ csrf, username = "", email = "" }) {
  return `<h1>Sign up</h1>
  <form method="post" class="form">
    <input type="hidden" name="csrf_token" value="${esc(csrf)}">
    <label for="username">Username</label>
    <input id="username" name="username" required maxlength="30" value="${esc(username)}">
    <label for="email">Email</label>
    <input id="email" name="email" type="email" required value="${esc(email)}">
    <label for="password">Password</label>
    <input id="password" name="password" type="password" required minlength="8">
    <p class="form-hint">At least 8 characters.</p>
    <button type="submit">Create account</button>
  </form>
  <p>Already have an account? <a href="/login">Log in</a>.</p>`;
}

export function searchPage({ query, posts }) {
  if (!query) {
    return `<h1>Search</h1>\n<p class="empty">Type something in the search box to find posts.</p>`;
  }
  const body = posts.length
    ? postListHtml(posts)
    : `<p class="empty">No posts match “${esc(query)}”.</p>`;
  return `<h1>Results for “${esc(query)}”</h1>\n${body}`;
}
