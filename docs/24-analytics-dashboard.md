# 24 — Analytics & Metrics (the comprehensive dashboard)

Three surfaces, one philosophy: **Today** (doc 23) is the worklist,
**Dashboard** is weekly health, **Reports** is drill-down. Every metric
below is computed from rows the app already records — nothing typed
twice, nothing kept in a spreadsheet. Every chart drills into the rows
behind it; every aggregate feeds the outbound templates (investor
monthly I6, team digest T9) — one source of truth for what you see and
what they're told.

---

## The six pillars

**Money · Pipeline · Delivery · People · Risk · Growth** — each a
dashboard section; the metric catalog is the contract between the
schema and the UI.

## 1. MONEY (the headline strip)

| Metric | Formula / source | Decision it drives |
|---|---|---|
| Cash position (recorded) | Σ payments + funds_received − Σ payouts paid + expenses + vendor payments | can I commit to this month? (reconcile w/ bank monthly, v9) |
| Revenue (collected) | Σ paid invoices, by month & kind | trend; template vs custom vs module mix |
| Outstanding / aging | unpaid invoices bucketed 0–7 · 8–30 · 31–60 · 60+ | who to chase today (links queue) |
| Win rate | accepted ÷ (accepted+rejected+expired) proposals | pricing & volume sanity |
| Average deal size | collected ÷ count, by kind | which segment to pitch |
| Project margin % | (revenue − team − procurement − investor returns) ÷ revenue, per project | which work to repeat (P&L links doc 19/21 waterfalls) |
| Zero-cash-outlay share | margin from investor-funded projects ÷ total margin | capital strategy |
| Payout obligations | blocked (contingent) vs payable (owed) vs paid MTD | cash forecasting; **"guard protected {X} this month"** = blocked payouts on unpaid invoices |
| Investor obligations | committed returns vs trigger-bound vs paid; realized losses | relationship & solvency view |
| Cost structure | team % + procurement % + allocated tools/utilities (doc 10) + investor returns %, stacked/month | where margin leaks |
| Recovery tracker | per defaulted project: recovered vs outstanding per investor (docs 20–21) | salvage status |

## 2. PIPELINE (sales engine)

Leads by stage (count + catalogue-weighted value) · new leads/week by
campaign · **median first-response time** (lead-created → first out in
comms_log) · **sequence funnel**: intro sent → replied → demo →
proposal → won, per-step conversion from outbox+comms_log · proposals
in flight (sent / follow-up due / expiring ≤7d / accepted / lost) ·
median time-to-close by source · campaign ROI (leads × closed revenue
attributed ÷ tool cost) · demo→proposal conversion ≤7d · salvage plays
running + value recovered so far.

## 3. DELIVERY

Active projects by status (incl. `on_hold` and `defaulted` counts) ·
module orders deployed/month (throughput) · median accepted→deployed
cycle · **review latency** (days waiting on client review/acceptance —
the silent killer, amber by default) · deployment health
(healthy/degraded/pending_agent) · median PO ordered→received · stuck
POs (>5d at ordered) · change-order rate per project (under-scoping
signal) · first-time-right (accepted without changes ÷ total reviews).

## 4. PEOPLE

**Team**: earnings per member (paid YTD + pending split blocked/payable)
· on-time vs late submissions · active assignments per member · median
accrued→paid days (your transparency metric — they see it too in T6/T7).
**Investors**: capital deployed vs outstanding principal vs returned ·
promised vs paid per investor (simple multiple: returned ÷ invested) ·
**concentration gauge** (one project's % of one investor's capital —
doc 20 gate #3, live) · investor-funded vs own-funded project ratio ·
repeat-round participation (loyalty signal — salvage round acceptances).
**Vendors**: on-time % · dispute rate · price variance (quoted vs
invoiced per PO).

## 5. RISK RADAR (the prevention gates, live)

Doc 20's six gates rendered as gauges, each linking to the offenders:

| Gauge | Computed from | Threshold (default, tunable) |
|---|---|---|
| Zero-deposit exposure | POs funded by advance on projects with no client payment | any > 0 → amber |
| Default radar | projects: procurement started + zero payments + days | > 14d → red |
| Concentration | investments: project ÷ investor capital | > 40% → amber |
| Margin floor | quote-time & realized margin per deal | < 25% → amber |
| Agency cash at risk | own-cash POs + unguarded outflows | design target: 0 |
| Overdue everything | invoices >14d · reviews >7d · acceptances >7d · POs >5d | per-item amber |
| Credential expiry | vault: expires_at ≤ 30d | amber |
| Template debt | client repos behind template latest tag (doc 11) | > 2 releases → amber |

## 6. GROWTH

Revenue by template/service (top & bottom) · template portfolio sold vs
available · **salvage-born templates' revenue** (doc 21 proof) ·
module-add-ons per client + upsell conversion (doc 5 opportunities) ·
recurring share of revenue (Lane C %) · revenue per client lifetime
(LTV proxy) · conversion by industry (hotel vs carwash vs aquarium —
the ICP engine from doc 21's post-mortem) · investor base: new vs
repeat.

## Dashboard layout

```
┌─ Week of 20 Oct ──────────────── [Run 15-min review →] ─┐
│ COLLECTED MTD  $18.5k ▲   OUTSTANDING  $9k (3)          │
│ CASH (recorded) $41.2k    PAYOUT DUE   $2.4k            │
│ PIPELINE 12 leads · 4 proposals · 1 expiring  MARGIN MTD 38% ▲ │
├─ Risk radar (3 amber) ─┬─ Money ───────────────────────┤
│ ⚠ 2 POs zero-deposit   │ aging bars · cost stack ·      │
│ ⚠ INV-38 16d overdue   │ obligations split (guard ▸)    │
│ ⚠ PO-7 stuck 6d        │ per-project waterfall cards    │
├─ Pipeline ─────────────┼─ Delivery ─────────────────────┤
│ funnel + stage counts  │ cycle/latency + deploy health  │
└────────────────────────┴────────────────────────────────┘
```

- **KPI strip**: big numbers with month-over-month deltas
- **Weekly review mode**: guided 15-minute flow through the six
  pillars, ending with a generated checklist (chases to send, decisions
  to make) that lands in Today's queue
- **Numbers page**: one printable/exportable page — the same
  aggregates rendered for the investor monthly (I6) or your own records

## Rules

1. Every chart drills to its rows (click aging bar → the invoices)
2. Zero manual entry in analytics — rows only; bank truth arrives via
   `bank_reconciliations` (monthly, one row)
3. Defaults tunable in `app_settings` (margin floor, concentration cap,
   overdue days)
4. What they see = what you see: I6/T9 templates render the same
   aggregates — no separate "investor version" of numbers
5. Charts without a decision attached don't exist

## Schema delta (v9)

`bank_reconciliations` (month UNIQUE, statement_balance,
recorded_balance, diff, note) + threshold keys in `app_settings`.
Everything else is SELECTs.
