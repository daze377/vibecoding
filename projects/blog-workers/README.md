# Blog on Cloudflare Workers + D1

The task-11 blog, ported from Flask + SQLite ([../blog](../blog)) to
**Cloudflare Workers + D1** so it runs 24/7 on the free plan — no computer
needed. Live at **https://blog.dazelu20.workers.dev**.

Same features, same routes, same CSS/JS, same security model:
accounts (PBKDF2-hashed passwords), author-only posts CRUD, comments and
like/dislike via JSON APIs, search with LIKE-escaping, light/dark theme,
signed-cookie sessions, CSRF tokens on every POST, CSP headers.

## Stack

| Flask version | This version |
|---|---|
| Flask routes | [Hono](https://hono.dev) routes (`src/*.js`) |
| SQLite file | D1 (SQLite-dialect, serverless) — same `schema.sql` |
| Jinja2 templates | template functions in `src/html.js` (auto-escaped) |
| Flask signed session | HMAC-signed cookie (`src/session.js`, Web Crypto) |
| Werkzeug password hash | HMAC pepper + PBKDF2 (`src/password.js`) |
| `static/` | `public/static/` — byte-identical files |

## Run locally

```bash
npm install
npx wrangler d1 execute blog-db --local --file=schema.sql   # once
npm run dev    # → http://localhost:8787
```

## Deploy

See the repo skill: [`skills/deploy-cloudflare-workers/SKILL.md`](../../skills/deploy-cloudflare-workers/SKILL.md)
(login → `d1 create` → schema → `wrangler deploy` → `secret put SECRET_KEY`).
Day-to-day it's just:

```bash
npx wrangler deploy
```

Free-plan budget: 100k requests/day, D1 5 GB / 5M row reads / 100k row
writes per day — far beyond a class blog's needs.
