# Blog — task-11

A small but complete personal blog: sign up, write posts, comment,
like/dislike, search, and a light/dark theme. Built with **Flask + SQLite**
the [task-11.md](task-11.md) way: brainstorm → plan → build with TDD → test → ship.

## Features

- **Accounts** — sign up, log in, log out (passwords stored only as hashes)
- **Posts** — create / edit / delete, author-only; home page lists newest first
- **Comments** — logged-in users comment via a JSON API; everyone can read
- **Reactions** — like / dislike, one per user; same click again removes it
- **Search** — find posts by words in the title or body
- **Theme** — light / dark toggle, remembered in `localStorage`
- **Security** — hashed passwords, CSRF tokens on every POST, parameterized
  SQL, Jinja auto-escaping, no open redirects

## Run it

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/flask --app app run --debug
# → http://127.0.0.1:5000  (tables are created automatically on first start)
```

## Test it

```bash
.venv/bin/pytest          # 45 tests, every feature covered
.venv/bin/pytest --cov    # coverage report (97% at the time of writing)
```

Tests follow the red → green → refactor loop described in task-11.md §9;
each feature landed as its own commit with its tests.

## Share it (deploy)

```bash
# 1. use a real secret key outside of local dev
export SECRET_KEY="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
export COOKIE_SECURE=1   # session cookie only over HTTPS (the tunnel is HTTPS)
.venv/bin/flask --app app run

# 2. in a second terminal — free public URL via Cloudflare Tunnel
cloudflared tunnel --url http://localhost:5000
```

Share the `https://….trycloudflare.com` URL it prints. Done!

> Demo-scale notes: this runs on Flask's dev server with SQLite, which is
> exactly what task-11 calls for (a live class demo). For anything bigger,
> put it behind a real WSGI server and add rate limiting.

## Project layout

```
app.py            # create the app, register routes
db.py             # open SQLite, create tables
models.py         # read/write users, posts, comments, reactions
csrf.py           # session-token CSRF protection for all POSTs
auth/             # sign up, log in, log out, sessions, hashing
posts/            # create / edit / delete / list / detail
comments/         # add comments (JSON API)
reactions/        # like / dislike, one per user (JSON API)
search/           # find posts by text
templates/        # Jinja2 pages
static/           # style.css, theme.js, post.js
tests/            # pytest suite — one file per feature
task-11.md        # the design doc this project follows
```
