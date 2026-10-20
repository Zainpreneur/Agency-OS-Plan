# 06 — Invoicing, Payments & Subscriptions

**Scope decision: no ZATCA.** Plain PDF invoices in the editorial brand
style, VAT as an optional field, payment via Tap/Moyasar links.

## Tables

```sql
invoices       (id, client_id, sale_id, number 'INV-2026-0042',
                status [draft|sent|viewed|paid|overdue|void],
                subtotal, vat, total, due_at, payment_link)
invoice_lines  (invoice_id, kind, description,
                ticket_id?, deployment_id?, qty, unit_price)   -- price snapshot
payments       (invoice_id, provider [tap|moyasar|bank],
                external_id, amount, paid_at)                  -- webhook-written
subscriptions  (client_id, name 'Website maintenance',
                amount 300, interval [monthly|yearly],
                status [active|paused|cancelled],
                started_at, next_invoice_at, cancelled_at)
```

## Rules

- **Line items should reference delivery reality** — "Branch 07 setup fee"
  (deployment_id), "Custom: delivery tracking page" (ticket_id) — so the
  client sees exactly what they paid for, and disputes are rare
- **Price snapshots**: a template price rise tomorrow never changes a sent
  invoice
- `payments` rows are written **only by webhooks**; manual "mark paid" is an
  `adjustment` with a reason
- Invoice numbering: `INV-2026-0042`, gaps forbidden (void rows keep the
  number)

## The subscription engine (your MRR)

- Cron on `next_invoice_at` → generates the monthly invoice (e.g. 300 SAR
  maintenance) and emails the payment link
- Invoice paid → `payments` webhook → subscription stays active
- **Cancelled subscription** stops generation, flips support SLA off, and
  (importantly) stops the team's `monthly_support` payout accrual — see doc 07
- Late payer → invoice `overdue` → auto-reminder + payout stays blocked

## Multi-branch clients

Milestone invoices tie to `deployments` rows:

```
INV-…-0051  Setup fee × 5 branches (branches 1–5 live)          7,500
INV-…-0058  Monthly SaaS × 15 live branches                      900
```

## Payment flow

```
invoice sent → tracked link viewed → payment.succeeded webhook
  → payments row → invoice paid
  → unblocks team payouts (payouts.unblock_payment_id)
  → project flips to in_progress (if your rule is "pay first")
```
