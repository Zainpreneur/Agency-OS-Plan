# 16 — Deployment Matrix (one pipeline, four adapters)

Heterogeneous client hosting: Vercel, Hostinger VPS, any PaaS, and a full
on-prem VPS in their office — one uniform pipeline and status model.

## Schema

```sql
deployment_targets (
  id, client_repo_id, env [staging|production],
  provider [vercel|hostinger_vps|generic_paas|office_vps],
  domain, credential_id,            -- API token / SSH key from VAULT
  env_vars_json,                    -- NAMES only; values live in vault
  deploy_method [api|ssh_script|agent_poll],
  status [never_deployed|healthy|degraded|pending_agent],
  last_deploy_at, current_sha, health_url)
```

## Adapter contract

```
deploy(sha) · rollback() · healthcheck() · logs()
```

| Client accepts | How the pipeline ships |
|---|---|
| **Vercel** | API token → link project → push env vars → deploy → preview URL for approval |
| **Hostinger VPS** | SSH key (vault) → git pull → build script → Nginx/systemd → health check |
| **Any PaaS** (Render/Railway…) | Provider API + deploy hook (same shape as Vercel) |
| **Office server (on-prem)** | **Pull-agent**: platform queues release, their box polls ~60s and pulls (no inbound firewall holes) + optional Tailscale tunnel for support. Status `pending_agent` when offline — deploy waits, dashboard says so |

## Uniform behavior regardless of target

- PR merges → adapter chosen by the project's target → deploy →
  `healthcheck` → `current_sha` updated → portal flips to
  *"Your app is live ✓"* (non-technical language)
- **Rollback = one button** on every provider
- Domains/SSL per adapter: Vercel auto · VPS = certbot/Caddy · office =
  LAN hostname + optional Cloudflare tunnel
- Deployment provider can be **priced as an attribute** (Vercel +0,
  Hostinger +150, Office VPS +500 setup) — see doc 17

## Payment gate

```
All production targets healthy
  + client clicks "I accept" (acceptance: time + IP)
  → invoice A (dev fee, snapshot price) + hardware PO invoices
  → payment webhook → maintenance mode begins
```

Custom build = pay-once at deploy · SaaS product = own subscriptions
engine · third-party tools = their card, your tracking (doc 15, Lane B).
