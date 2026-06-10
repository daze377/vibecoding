---
name: deploy-blog-workers
description: Deploy or redeploy the blog (projects/blog-workers) to Cloudflare Workers + D1 on the free plan. Use when asked to deploy the blog to Cloudflare, push blog changes live, update the production blog, or set up the Workers deployment from scratch.
---

# Deploy the blog to Cloudflare Workers + D1

The full, verified runbook lives at **`skills/deploy-blog-workers/SKILL.md`**
(repo root — kept there as visible course material). Read that file and
follow it exactly; it covers the redeploy loop, first-time setup (login,
D1 create, subdomain registration via API, secret), live verification via
curl, local dev, and the known gotchas.

Quick reference — day-to-day redeploy is just:

```bash
cd projects/blog-workers && npx wrangler deploy
```
