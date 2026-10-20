# 10 — Cost Allocation (tools, utilities, true margin)

The cost side of the ledger — closing the P&L loop started by invoices and
payouts. Three kinds of spend:

```
RECURRING TOOLS   Claude Code sub, GitHub Copilot, hosting, domains…
ONE-TIME          lifetime deals, fonts, hardware
UTILITIES         electricity, WiFi, rent — the hidden cost of "free" tools
```

## Tables

```sql
vendors      (id, name, category [saas|utility|hardware|contractor|ads])
tool_costs   (id, vendor_id, name, plan, seats,
              amount, currency, sar_amount, fx_rate,
              interval [monthly|yearly|one_time], next_renewal_at,
              status [trial|active|paused|cancelled],
              allocated_by [hours|flat|equal], cancel_url)
tool_charges (id, tool_cost_id, paid_at, amount, sar_amount, fx_rate,
              period_from, period_to, receipt_url)   -- written by renewal cron
expenses     (id, date, vendor_id, kind[subscription|utility|hardware|contractor|ads],
              description, amount, currency, sar_amount,
              tool_cost_id, project_id, client_id,
              receipt_url, payment_method, notes)    -- THE ledger
shared_costs (id, month, kind[electricity|wifi|rent|device_depreciation],
              total_sar, allocation[hours|equal], allocations JSONB)
```

## The allocation engine (why "free" isn't free)

Nobody hand-assigns tool costs. A monthly job spreads `shared_costs` and
non-project `tool_costs` across projects using **hours already tracked**:

```
October hours: Carwash 62 · Furniture 48 · Laundry 30 · Internal 20 = 160

Claude Code 375 + Electricity 420 + WiFi 260 + Depreciation 666 → same split
Furniture's share: tools 111 + utilities/depreciation 252 → true cost visible
```

- `allocated_by='flat'` overrides: a GitHub org used for one client's
  delivery repo → 100% to that project
- Free tools (OpenCode) get a **0-SAR `tool_costs` row** — their real cost
  appears through utilities + hours, making free-vs-paid comparisons honest

## Monthly ritual (5 minutes, 1st of month)

```
[ Enter October bills ]  Electricity 420 · WiFi 260 · device depreciation auto
  → shared_costs row written; allocations computed from time_entries
```

## FX rule

Store `sar_amount` + `fx_rate` **at charge time**. A yearly USD charge
refunded/charged-back later must reconcile to the exact amount.

## Ledger discipline

- `tool_costs` is the *schedule*; `tool_charges`/`expenses` are the *facts*.
  A price change = new row on `tool_costs`; history is never edited
- Renewal cron notifies 3 days before `next_renewal_at`, then writes the
  charge + expense rows on the day

## The reports

```
OCTOBER 2026
Revenue (paid invoices)              33,000
Costs: tools 1,012 · utilities+depr 880 · contractors 4,000 · ads 800
Net                                  27,300   (82.7% margin)

Per-client true margin (after payouts + allocation):
  Carwash   12,000 − 3,140 = 8,860 (74%)
  Furniture  9,000 − 2,210 = 6,790 (75%)
  Laundry    3,000 −   980 = 2,020 (67%)

Tool ROI:  Claude 375/mo → touched 5 projects, 140h, revenue 30,000 → keep ✓
           Ads 800 → 7 wins / 21,000 → cost per win 114 ✓
Renewals next 30d: Claude Code (Nov 3) · Copilot (Nov 7)
```

**True margin formula (the whole point):**
`revenue − team payouts − allocated tools − utilities/depreciation − ads`
