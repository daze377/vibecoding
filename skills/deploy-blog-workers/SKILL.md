---
name: deploy-blog-workers
description: Deploy or redeploy the blog (projects/blog-workers) to Cloudflare Workers + D1 on the free plan. Use when asked to deploy the blog to Cloudflare, push blog changes live, update the production blog, or set up the Workers deployment from scratch.
---

# Deploy the blog to Cloudflare Workers + D1

The Workers port of the task-11 blog lives in `projects/blog-workers`
(Hono + D1; same routes, templates, and JS assets as the Flask version in
`projects/blog`). Result: the blog runs 24/7 on Cloudflare's free plan —
no personal computer involved. Everything below was executed and verified
end-to-end on 2026-06-10 (live at `https://blog.<subdomain>.workers.dev`).

All commands run from `projects/blog-workers`. The project's pinned wrangler
is used via `npx wrangler` (do not install globally).

## Redeploy after a code change (the common case)

```bash
cd projects/blog-workers
npm install          # only needed once per machine
npx wrangler deploy  # bundles src/ + public/ and goes live in seconds
```

If `schema.sql` changed, apply it to the remote database too:

```bash
npx wrangler d1 execute blog-db --remote --file=schema.sql -y
```

Then verify (see "Verify the live site" below). That's the whole loop.

## First-time setup on a new machine or account

1. **Login** (browser OAuth — the only step needing a human click):

   ```bash
   npx wrangler login --browser=false   # prints a URL; open it, click Allow
   npx wrangler whoami                  # MUST show the intended account email
   ```

   Run login in the background, grep the URL from its output, and `open` it.
   The link expires after a few minutes — regenerate if it times out.

2. **Create the database** and wire it up:

   ```bash
   npx wrangler d1 create blog-db
   ```

   Copy the printed `database_id` into `wrangler.jsonc` (keep the binding
   name `DB`), then create the tables:

   ```bash
   npx wrangler d1 execute blog-db --remote --file=schema.sql -y
   ```

3. **Register the workers.dev subdomain** (first deploy only). Interactive
   `wrangler deploy` prompts for this, but prompts fail in non-TTY shells
   (they auto-answer "no"). Register via API instead — the OAuth bearer
   token lives in `~/Library/Preferences/.wrangler/config/default.toml`:

   ```bash
   TOKEN=$(grep -m1 'oauth_token' "$HOME/Library/Preferences/.wrangler/config/default.toml" | sed 's/.*= *"//;s/"//')
   ACC=$(npx wrangler whoami 2>&1 | grep -o '[0-9a-f]\{32\}' | head -1)
   curl -s -X PUT "https://api.cloudflare.com/client/v4/accounts/$ACC/workers/subdomain" \
     -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
     --data '{"subdomain":"CHOOSE_A_NAME"}'
   ```

   Never print the token itself.

4. **Deploy, then set the session secret** (worker must exist before
   `secret put`):

   ```bash
   npx wrangler deploy
   openssl rand -hex 32 | npx wrangler secret put SECRET_KEY
   ```

   The URL is `https://blog.<subdomain>.workers.dev`. A brand-new subdomain
   takes ~1–2 minutes of DNS propagation — `curl` returns code 000 until
   then; wait 30s and retry rather than debugging.

## Verify the live site

Drive the real user journey with curl (CSRF token must be carried; forms
send it as a `csrf_token` field, the JSON API as an `X-CSRF-Token` header):

```bash
B=https://blog.<subdomain>.workers.dev
T=$(curl -s -c jar.txt $B/signup | grep -o 'name="csrf_token" value="[^"]*"' | head -1 | sed 's/.*value="//;s/"//')
curl -s -b jar.txt -c jar.txt -o /dev/null -w "signup: %{http_code}\n" \
  -d "csrf_token=$T&username=demo&email=demo@example.com&password=password123" $B/signup
# expected: signup 302; same pattern for /login (302), /new (302);
# POST $B/api/post/1/comment with X-CSRF-Token → 201;
# POST without the header → 400; GET /post/999 → 404
```

Pass criteria: home 200 with the post list, signup/login/new 302,
comment 201, react `{"ok":true,...}`, missing CSRF → 400, security headers
(`content-security-policy`, `x-frame-options`) present on every page.

## Local development

```bash
npx wrangler d1 execute blog-db --local --file=schema.sql  # once
npm run dev                                                # http://localhost:8787
```

Local D1 state lives under `.wrangler/` (gitignored); `.dev.vars` provides
`SECRET_KEY` and `DEV=1` (disables the cookie Secure flag for http).

## Gotchas learned the hard way

- Wrangler's interactive prompts auto-answer "no" in non-TTY shells — any
  step that would prompt (subdomain registration, config rewriting) must be
  done explicitly, as above.
- `wrangler secret put` before the first deploy fails: deploy first.
- Tail logs when debugging production: `npx wrangler tail blog`.
- Free-plan CPU is ~10 ms/request; password hashing (PBKDF2, 100k
  iterations in `src/password.js`) is the only heavy path — if signup/login
  ever hits CPU errors (1102), lower `ITERATIONS` and redeploy.

## Free-plan budget (why this is enough)

100,000 requests/day; D1: 5 GB storage, 5M row reads/day, 100k row
writes/day. A class blog uses well under 1% of all of these.
