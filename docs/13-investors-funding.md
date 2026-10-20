# 13 — Investors & Funding

Other people's money funds big builds. It's a **liability, not revenue** —
tracked per project and distributed by a snapshotted waterfall, with the
same blocked→payable cash-flow guard the team payouts use.

## Schema

```sql
investors        (id, name, contact, iban, notes)

project_funding  (id, project_id,
                  target_amount,              -- 30,000
                  status [seeking|committed|funded|returned|closed],
                  terms_summary, agreement_url)   -- signed doc, immutable

investments      (id, funding_id, investor_id,
                  amount,                     -- 10,000
                  promised_return,            -- 15,000 (snapshot)
                  return_rule [fixed|multiple|revenue_share],
                  invested_at, funds_received_at)

investor_payouts (id, investment_id, amount,
                  status [accrued|blocked|payable|paid],
                  trigger_payment_id,         -- client's 50k payment unblocks
                  payable_at, paid_at, paid_via)

funding_waterfalls (funding_id, order_no,
                    target [investors|agency], pct, cap)  -- distribution recipe
```

## Worked example (30k in → 45k out → 5k agency)

```
Round: Farm-IoT · target 30,000 → committed
  A 10,000 → promised 15,000 · B 10,000 → 15,000 · C 10,000 → 15,000
Waterfall:  1) investors pro-rata of promised   2) agency residual

Funds arrive → recorded as project-restricted cash (never mixed with ops)
  app shows: funded 30,000 · deployed to costs 21,400 · remaining 8,600

Client milestone invoice 50,000 → PAID (webhook)
  waterfall fires: 3 × 15,000 = 45,000 → investor_payouts accrued
                                          → UNBLOCKED by this payment
                  residual 5,000 → agency revenue
  Friday payout run: pay 3 × 15,000 ✓
```

## Rules

- **Returns stay `blocked` until client receipts** — if GreenFields pays
  late, investor payouts wait; your personal cash never bridges the gap
  silently (agreements should say "paid from project receipts")
- Terms (`promised_return`, `return_rule`) are snapshotted at investment
  time — later deal changes are new rows, never edits
- **Concentration alert** when one investor holds >50% of a single project

## Investor relations surfaces

- Read-only portal view (like the team's): investments, promised vs
  received, returned YTD — "when do I get my return" answers itself
- Auto statements per event: "Farm-IoT closed · 15,000 returned Oct 30 ·
  IRR 50% on 90-day hold"
- Pipeline view: `seeking` → who to pitch; `committed` → who's exposed to what
