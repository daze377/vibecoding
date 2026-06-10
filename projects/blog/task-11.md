# task-11.md — Blog System Design

> A complete plan for the AI agent to follow, written the **Superpowers** way:
> brainstorm → plan (this file) → build with TDD → test → ship.
> Keep this file in your project root and update it as the design changes.

---

## 1. Overview
Build a small but complete personal **blog**. A signed-in user can write posts;
visitors can read posts, leave comments, and react (like / dislike). Finally,
put it online with Cloudflare so friends can visit.

## 2. Goals / Non-Goals
**Goals**
- A working blog that runs on one machine and can be shared publicly.
- Clean, readable code a beginner can follow.
- Safe sign-up / log-in (passwords are never stored as plain text).

**Non-Goals (keep it simple)**
- No payments, no admin dashboard, no multiple blogs per server.
- No fancy frontend framework required (plain HTML/CSS/JS is fine).

## 3. Requirements
### Functional
- **Accounts:** sign up, log in, log out.
- **Posts:** create, edit, delete (author only); each post has a title + body.
- **Home page:** list posts, newest first (title, short preview, date).
- **Post page:** full post + its comments.
- **Comments:** a logged-in user can add a comment; everyone can read them.
- **Reactions:** like / dislike a post (one choice per user).
- **Search:** find posts by words in the title or body.
- **Theme:** light / dark toggle.

### Non-Functional
- Passwords hashed (e.g. Werkzeug `generate_password_hash`).
- Pages work on a phone screen.
- Loads fast enough for a live class demo.
- Every feature has at least one automated test.

## 4. Tech Stack
| Layer | Choice | Why |
|-------|--------|-----|
| Backend | **Python + Flask** | Simple, one language, great for beginners |
| Database | **SQLite** | Built in, just one file, no server to run |
| Templates | **Jinja2** (HTML) | Renders pages with your data |
| Frontend | HTML + CSS + a little JS | Theme toggle, small interactions |
| Tests | **pytest** | Fast, runs without a real server |
| Deploy | **Cloudflare Tunnel** | Free public URL for your local app |

*Optional later:* swap the frontend for React or Vue.

## 5. Architecture / Module Division
```
blog/
  app.py            # create the app, register routes
  db.py             # open SQLite, create tables
  models.py         # read/write users, posts, comments, reactions
  auth/             # sign up, log in, log out, sessions, hashing
  posts/            # create / edit / delete / list / detail
  comments/         # add + list comments
  reactions/        # like / dislike (one per user)
  search/           # find posts by text
  templates/        # base.html, index.html, post.html, login.html, edit.html
  static/           # style.css, theme.js
  tests/            # test_auth.py, test_posts.py, test_comments.py ...
  task-11.md        # this design file
```

## 6. Database Schema
```
users
  id            INTEGER PK
  username      TEXT UNIQUE NOT NULL
  email         TEXT UNIQUE NOT NULL
  password_hash TEXT NOT NULL
  created_at    TEXT  (timestamp)

posts
  id         INTEGER PK
  author_id  INTEGER -> users.id
  title      TEXT NOT NULL
  body       TEXT NOT NULL
  created_at TEXT
  updated_at TEXT

comments
  id         INTEGER PK
  post_id    INTEGER -> posts.id
  user_id    INTEGER -> users.id
  body       TEXT NOT NULL
  created_at TEXT

reactions
  id       INTEGER PK
  post_id  INTEGER -> posts.id
  user_id  INTEGER -> users.id
  kind     TEXT  ('like' | 'dislike')
  UNIQUE(post_id, user_id)   -- one reaction per user per post
```
Sessions are handled by Flask's signed cookie (no table needed).

## 7. Routes (Pages + API)
**Pages**
```
GET  /                 home: list posts
GET  /post/<id>        one post + comments
GET  /signup           sign-up form
POST /signup           create account
GET  /login            log-in form
POST /login            start a session
POST /logout           end the session
GET  /new              new-post form          (login required)
POST /new              save a new post        (login required)
GET  /edit/<id>        edit-post form         (author only)
POST /edit/<id>        save edits             (author only)
POST /delete/<id>      delete a post          (author only)
GET  /search?q=...     search results
```
**JSON API**
```
POST /api/post/<id>/comment   add a comment   (login required)
POST /api/post/<id>/react     like/dislike    (login required)
```

## 8. Task Breakdown (build in this order — one test first, then the code)
1. **Setup + DB + base page** — app starts, `GET /` returns 200.
2. **Auth** — sign up, log in, log out; passwords hashed; protected route blocks guests.
3. **Posts CRUD** — author can create/edit/delete; other users cannot.
4. **Home list + post page** — newest first; post page shows the full body.
5. **Comments** — a logged-in user can comment; the comment appears on the post.
6. **Reactions** — like/dislike; only one per user; counts update.
7. **Search** — a query returns only matching posts.
8. **Light/Dark theme** — toggle works and is remembered.
9. **Deploy** — Cloudflare tunnel gives a public URL that loads the home page.

## 9. Testing Plan
- Use **pytest** with Flask's test client (no real server needed).
- For each task: **red** (write a failing test) → **green** (make it pass) → **refactor**.
- Must-test cases: right status codes, auth rules, data is saved, and edge cases
  (empty title, wrong password, comment while logged out).

## 10. Definition of Done + Workflow
- A task is done when its tests pass **and** it's committed:
  `git add .` → `git commit -m "feat: add comments"` → `git push`.
- Keep functions small, names clear, and comment any tricky part.
- Follow the Superpowers loop: **brainstorm → plan (this file) → build with review → test**.

## 11. Deploy (make it public)
```
cloudflared tunnel --url http://localhost:5000
```
Share the public URL it prints. Done!

---

## 12. Implementation Notes (added as built — June 2026)

Small deviations from the plan above, recorded per the "update this file" rule:

- **`csrf.py`** was added: every POST (forms + JSON API) requires a
  session-bound CSRF token. Forms send a hidden `csrf_token` field; the API
  sends an `X-CSRF-Token` header read from a meta tag in `base.html`.
- The SQL schema lives **inside `db.py`** (no separate `schema.sql`), and
  tables are auto-created at startup, so `flask --app app init-db` is optional.
- `comments` / `reactions` rows are deleted **via `ON DELETE CASCADE`** when
  their post is deleted.
- Reactions are a **toggle**: clicking your current reaction removes it;
  clicking the other kind switches it (still one row per user per post).
- Extra templates beyond the original list: `signup.html`, `search.html`, and
  a shared `_post_list.html` partial (used by home + search).
- Tests live one-file-per-feature with a `conftest.py` providing a fresh
  temp-file database per test; suite coverage is ~97%.
