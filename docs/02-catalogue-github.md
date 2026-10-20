# 02 — Catalogue & GitHub Integration

Your sellable products are the GitHub template repos. The catalogue is a
**mirror**, never a second source of truth.

## GitHub App, not a PAT

- Installed on the `Zainpreneur` org, scoped per repo
- Survives token expiry; lets client delivery repos be installed later
- Permissions: contents (R), metadata (R), webhooks (RW), pages (W)

## The `template.json` manifest (lives in each template repo)

```json
{
  "slug": "laundry-shop",
  "category": "business_software",
  "name": "Laundry Shop Business Software",
  "list_price": 4000,
  "tier": "extended",
  "demo": { "seed_from": ["google_maps", "client_website"] },
  "addons": ["multi_branch", "pos", "delivery_tracking"]
}
```

A nightly cron upserts `templates` from every repo's manifest + metadata
(topics, language, last push). **Releases/tags = sellable versions** — a new
tag bumps "current version" on the catalogue card automatically.

## Tables

| Table | Purpose |
|---|---|
| `templates` | Mirrored manifest: price, tier, category, latest_tag, repo_url |
| `github_events` | Raw webhook payloads (`delivery_id` unique) → idempotent processing |

## Webhooks

| Event | Effect |
|---|---|
| `release.published` | Bump `templates.latest_tag`; notify: "new sellable version" |
| `issue.opened` | If on a client delivery repo → create a support `tickets` row |
| `issue.labeled` | Label (`bug`/`customization`/`retainer`) sets ticket type |
| `push` (delivery repo) | Log activity on the client's project timeline |
| `pull_request.merged` | Note progress on the linked ticket/project |

## Demo repo pipeline

```
[Build demo from template ▾]                       (one button)
  1. gh repo create Zainpreneur/demo-<slug> --template <template-repo> --private
  2. inject business data (name, address, phone, hours, reviews)
  3. git push
  4. enable GitHub Pages via API
  5. mint short link yourdomain.d/r/:code → records demo_opened on every hit
  6. demos row: status=live, expires_at = now + 30 days
```

- Cron archives demos whose lead went `lost` or whose `expires_at` passed
  (demos living forever become security debt)
- On client conversion the demo repo is promoted/archived; the real build
  happens in a dedicated private delivery repo (installed with the GitHub App)

## Why short links, not raw Pages URLs

- Every open is attributable (`lead_activities`, `campaign_id` attached)
- Opens feed the pipeline: "Al-Noor opened the demo 4×" → call-now signal
- Expiry and revocation stay under your control
