# 04 — Demos & Proposals

## Demos — the artifact that wins deals

| Field | Purpose |
|---|---|
| `lead_id` / `client_id` | Cold prospect OR existing client (upsell) |
| `template_id` | Which template it was cloned from |
| `repo_name` / `repo_url` / `github_pages_url` | The GitHub trail |
| `short_link` | Redirector that records every open |
| `status` | building → live → archived |
| `expires_at` | now + 30 days; cron archives on expiry or lost lead |
| `view_count` / `last_viewed_at` | "opened 4× today" = call-now signal |

### Demo personalization is the conversion trick

- **Cold lead:** template + their Google Maps data (name, address, phone,
  hours, photos)
- **Upsell to a software owner:** build the website demo **from the data
  already in their software** (services, prices, photos) — it's their shop
  on the page, 10× more persuasive
- **Upsell to a website owner:** software demo **seeded by scraping their
  site** (branding colors, catalog, contacts) — it already knows their world

## Proposals — price discipline

```sql
proposals:
  list_price      5000   -- snapshot of template price at proposal time
  offered_price   3000   -- the negotiation lives here
  discount_reason 'launch discount / first proposal'
  valid_until     +14d   -- legitimate urgency
  status: draft → sent → viewed → accepted / rejected / expired
```

**Rule: you never edit the 5000 to show 3000.** Both numbers are permanent
history → the dashboard can answer "am I discounting too much, by source?"

`proposal_lines`: kind (website_build | maintenance | addon | customization),
description, qty, unit_price (snapshotted). Example:

```
Proposal PROP-2026-014 — valid 14 days
  Website build (5 pages, WhatsApp CTA, Maps embed)     5,000
  Offered price                                          3,000   (−40%)
  + Website maintenance                                    200/mo
```

Sent as PDF **and** a tracked link → `proposal_viewed` activity fires the
moment they open it.

## Convert to client (one transaction)

```sql
INSERT clients  (lead_id UNIQUE, …);
INSERT sales    (client_id, proposal_id, price=accepted_price, delivery_repo);
INSERT subscriptions (amount=200, interval='monthly', status='active',
                      next_invoice_at = now()+30d);      -- if maintenance sold
INSERT invoices (total=accepted_price, status='sent', payment_link);
UPDATE proposals SET status='accepted', accepted_at=now();
UPDATE leads     SET status='won';
-- demo repo archived; template repo promoted to delivery repo
```

## Notes

- Proposals carry `lead_id` OR `client_id` — the same engine serves cold
  leads and warm upsells
- Accepted proposals feed `payouts` accrual (builder's 500) per comp plans
- Rejected/expired proposals record a reason → feeds win-rate analytics
