# 08 — Assets (5 laptops)

An agency laptop is not inventory — it's a **cost center that depreciates,
carries licensed software, logs billable hours, and breaks sometimes**.

## Lifecycle

```
purchased ─► in_use ─► reassigned … ─► in_repair ─► in_use ─► retired ─► disposed
```

## Tables

```sql
assets             -- asset_tag ZP-LAP-01…05 (QR sticker), make/model/serial,
                   -- specs JSON, purchase_cost, warranty_until,
                   -- depreciation_months (36), status, condition,
                   -- current_holder_id (fast index only)
asset_assignments  -- full history: who held what, when, condition_at_handover
maintenance_schedules -- cleaning/thermal-paste every 90d, battery check,
                       -- backup verify, insurance renewal, next_due_at
maintenance_logs      -- performed_at, cost_sar, vendor, downtime_hours,
                      -- issue_reported, resolution, invoice_url
asset_licenses        -- links a tool_costs seat to a physical machine
disposals             -- method sold|traded|donated|scrapped, proceeds_sar
```

Plus: `time_entries.device_id` — every logged hour knows which laptop it
ran on (device pinned at session login).

## Usage & utilization

```
ASSET REGISTER — Oct 2026
Asset     Holder   Hours Util% Book value Maint cost Cost/h
ZP-LAP-01 You       142   92%   9,300      0          2.6
ZP-LAP-02 Dev A      88   60%   6,600    180 (paste)  3.1
ZP-LAP-03 —          12    8%   4,980      0          —  ⚠ idle
ZP-LAP-04 Pool       0     0%   3,320      0          —  ⚠ reclaim
ZP-LAP-05 InRepair   —     —    1,660    120          —  ⚠ downtime 5d
```

Decision rule surfaced by the app: **when cost/h > renting a replacement +
your effective rate, the asset is a replacement/sale candidate.**

## Maintenance ritual

- Cron surfaces due items: "ZP-LAP-02 battery check overdue 6d",
  "ZP-LAP-04 insurance renews Nov 12", "ZP-LAP-01 warranty expires Dec 3"
- Logging a job writes `maintenance_logs` + `expenses(kind=hardware)`;
  downtime hours feed utilization (visible when a laptop died during crunch)

## Integration with the rest

| Module | Link |
|---|---|
| Team | Member's current laptop = `assets.current_holder_id`; shown on team page |
| Payouts | Offboarding = return laptop before final payout run |
| Licenses | `asset_licenses.tool_cost_id` — retiring a laptop lists which seats (Claude, Copilot) to cancel or move |
| Cost allocation | Depreciation (24,000 ÷ 36 = **666 SAR/mo**) is written to `shared_costs` monthly and allocated onto projects by hours |

## Rules

- Asset tag + QR sticker — scanning the physical machine opens its record
- Assignments are **history**, not a field (answer "who had it in March?")
- Retirement checklist: move licenses → wipe disk → log disposal → stop
  depreciation → update book value
- Depreciation cron only counts `status IN (in_use, in_repair, in_storage)`
