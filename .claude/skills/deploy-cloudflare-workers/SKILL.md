---
name: deploy-cloudflare-workers
description: Deploy any project to Cloudflare Workers + D1 on the free plan — one-time account setup, per-project setup (wrangler.jsonc, D1, secrets), day-to-day redeploys, and live verification. Use when asked to deploy a project to Cloudflare or Workers, put an app online for free, add a D1 database, or troubleshoot a wrangler deploy. Worked example: projects/blog-workers.
---

# Deploy a project to Cloudflare Workers + D1

The full, verified runbook lives at **`skills/deploy-cloudflare-workers/SKILL.md`**
(repo root — kept there as visible course material). Read that file and
follow it exactly. It covers: what a project needs (`wrangler.jsonc`,
schema, secrets-with-fallback), the one-time account setup (OAuth login,
subdomain registration via API), per-project first deploy (D1 create →
schema → deploy → `secret put`), day-to-day redeploys, live verification,
and the known gotchas (non-TTY prompts, secret-after-deploy ordering,
DNS propagation, free-plan CPU limits).

Quick reference — day-to-day redeploy of an existing project:

```bash
cd <project-dir> && npx wrangler deploy
```
