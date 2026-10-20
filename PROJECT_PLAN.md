# PROJECT PLAN — Agency OS

The complete design, in the order the business actually flows.
Scenarios used throughout: a **carwash** client with 15 branches, a **laundry**
shop found on Google Maps with no website, and a **furniture** campaign of 200
leads.

---

## 1. Catalogue (GitHub as the product database)

Your sellable products are GitHub repos (`*-Business-Software` templates).
Each repo carries a `template.json` manifest (price, tier, demo URL, category,
addons) so the catalogue is **data-driven**. A GitHub App (not a PAT) is
installed on your org; a cron syncs repo metadata, topics, and
**releases/tags** — a release is a sellable version.

- `templates` table mirrors the repos
- `github_events` stores raw webhook payloads for idempotent processing
- Release published → catalogue "latest sellable version" bumps automatically

## 2. Leads & Marketing campaigns (200 furniture leads)

`leads` captures discovery (Google Maps URL, has_website=false, source). At
200-lead scale you need **campaign × lead attribution**, not a `source` column:

- `campaigns` — the effort (WhatsApp sequence, ads, referral), budget, spend,
  message variant A/B
- `campaign_targets` — one row per campaign×lead×step, with the **rendered
  message body stored** for audit
- `sequence_steps` — Day 0 WhatsApp, Day 3 follow-up, Day 7 call task,
  Day 14 email; `stop_on_reply` pauses automation when a human answers
- A sender cron paces ~25 sends/day (never blast 200 at once)
- `leads.first_campaign_id` + `converting_campaign_id` = first-touch and
  last-touch attribution for cost-per-win and channel ROI

**Funnel dashboard:** targeted → sent → opened → replied → demo → proposal →
won, with cost per reply, cost per win, revenue per campaign, variant A vs B.

## 3. Demos (the artifact that wins deals)

A demo is one click: clone a template repo into `demo-<slug>`, inject the
prospect's scraped data (name, address, phone, hours), push, enable GitHub
Pages, mint a **short link** (`yourdomain.d/r/abc123`) that redirects to Pages
and records a `demo_opened` activity. Demos expire in 30 days and archive
automatically.

- Cold lead: generic-template demo with scraped Google Maps data
- Upsell (software owner): demo built **from their own software data**
- Upsell (website owner): software demo **seeded from their website**

## 4. Proposals (price discipline)

`proposals` snapshot **list_price (5000) → offered_price (3000) →
accepted_price**, so a future template price rise never rewrites history, and
"how much do I discount" becomes a measurable metric. Tracked links fire
`proposal_viewed` — you know the moment they open it. `valid_until` creates
legitimate urgency.

## 5. Conversion (win) — one transaction

`Convert to client` writes: `clients` (lead_id unique), `sales`, first
`invoices` (setup fee + payment link), and if there's a maintenance plan, a
`subscriptions` row (auto-invoices every 30 days — nobody remembers anything).
Lead status flips to `won`; the demo repo archives.

**Lost matters too:** `lost_reason` (price / no_response / diying) → "no"
re-opens in 6 months as a warm re-proposal.

## 6. Clients, Projects, Tickets & the Upsell Matrix

Client 360 page shows the product-need matrix:

```
                          Website  Software  Maintenance  POS
Al-Noor Carwash             ✗         ✓           ✓        ✗   → upsell WEBSITE
Furniture Store             ✓         ✗           ✗        ✗   → upsell SOFTWARE
```

A nightly rules job (`upsell_rules`: has_category X, missing Y → suggested
template Z) writes `opportunities`. Tickets tagged `feature_request`
auto-create hot opportunities with the ticket as `reason_detail`. Won upsells
are **expansion revenue** — the cheapest revenue you'll ever make. Dismissed
opportunities must record why; "not now" re-opens in 90 days.

Support tickets link to GitHub issues (issue opened → ticket created; labels
choose type). The maintenance subscription grants the SLA queue — that's what
makes 200–300/mo recurring instead of favors.

## 7. Invoicing, Payments & Subscriptions

`invoices` + `invoice_lines` (line items reference tickets/PRs/deployments so
clients see what they paid for), `payments` via Tap/Moyasar webhook —
`payment.succeeded` flips invoice to paid and **unblocks team payouts**.
**No ZATCA** — plain PDFs in the editorial brand style, VAT optional field.
One-time prices and recurring subscriptions share the same client record.

## 8. Team Payouts (only paid when something sells)

Three team members, revenue-share only:

- `comp_plans` — rules: builder gets **500 one-time** on `invoice_paid`;
  maintainer gets **100/mo** while `subscription_active`
- `payouts` lifecycle: `accrued → blocked → payable → paid`
  - **blocked** = waiting for the client to actually pay (cash-flow guard)
  - **payable** = client money arrived; next Friday run pays it
  - subscription cancelled → future monthly accruals stop automatically
- Team page shows each member, their assigned laptop, blocked/payable totals
- Offboarding checklist: return laptop + cancel license seats + pause future
  accruals + offer buyout of accrued
- Alert if a client's cumulative payouts exceed their lifetime revenue

Example: 3,000 website + 300/mo maintenance → team 500 + 100/mo →
**you keep 2,500 + 200/mo recurring.**

## 9. Assets (5 laptops)

`assets` register with asset tags + QR stickers (ZP-LAP-01…05):

- `asset_assignments` — full history of who held what, when, condition
- `time_entries.device_id` — every logged hour knows which laptop it ran on →
  utilization report (busy / underused / idle 41 days → reclaim)
- `maintenance_schedules` (cleaning every 90d, battery check, insurance
  renewal, warranty expiry alerts) + `maintenance_logs` with cost & downtime
- `asset_licenses` links `tool_costs` seats to physical machines — retiring a
  laptop tells you which subscriptions to cancel or move
- Depreciation (24,000 SAR ÷ 36 months = 666/mo) feeds `shared_costs`
- Disposal row: sold/traded/scrapped, proceeds, depreciation stops

## 10. Cost Allocation (the "free tools still cost electricity" answer)

- `tool_costs` — recurring subscriptions (Claude Code 100 USD/mo, Copilot,
  hosting), with `sar_amount` + `fx_rate` frozen at charge time; renewal cron
  auto-writes the `expenses` row and notifies 3 days ahead
- `expenses` — the single ledger of everything leaving your account
  (subscription / utility / hardware / contractor / ads)
- `shared_costs` — monthly electricity + WiFi + depreciation, **allocated onto
  projects by tracked hours**:

```
Oct hours: Carwash 62 · Furniture 48 · Laundry 30 · Internal 20 (=160)
Claude 375 SAR + Electricity 420 + WiFi 260 + Depreciation 666 → same split
```

- Free tools (OpenCode) get a 0-SAR row — their real cost appears through
  utilities + your hours, making the free-vs-paid comparison honest
- **Reports:** monthly burn, per-client true margin
  (revenue − payouts − tools − utilities), tool ROI (revenue touched per
  subscription), renewal calendar, cost-per-hour per asset

## 11. Multi-Branch (carwash, 15 branches)

The *product you sell* supports multi-branch with one DB, one app — branches
are rows:

- `businesses` = tenant root; **every table carries `business_id`**
  (denormalized for Row-Level Security later); `branch_id` on every
  transactional row
- **Shared vs scoped:** customers & vehicles are business-scoped (the car
  follows the customer across all 15 branches); sales, bookings, shifts,
  inventory are branch-scoped
- **Config hierarchy:** business default price list → `branch_services`
  overrides (airport branch +20%)
- **RBAC:** `memberships(user, branch_id, role)` — cashier sees only own
  branch; owner has branch_id = NULL = all branches
- Devices (POS tablets) are pinned to a branch — kiosk login auto-scopes
  every write; adding branch #16 is an INSERT, not a server
- `daily_branch_sales` rollups make the HQ dashboard O(15), not O(1M)
- **Four pitfalls:** never store branch names (IDs + snapshots only); never
  branch-scope customers; always snapshot unit_price on line items; scope in
  the query layer, not the frontend

Your Agency OS mirrors this with a `deployments` table (one row per branch,
rollout status sold→config→live) so sales, milestone invoices, and tickets all
know which of the 15 branches they belong to.

---

## Delivery order (MVP → v1.5)

| Phase | Scope |
|---|---|
| Week 1 | GitHub sync → Catalogue; Clients + Sales; invoice PDF + payment link |
| Week 2 | Lead intake; campaign sender + short links; demo builder |
| Week 3 | Proposals (snapshot pricing); convert-to-client transaction |
| Week 4 | Payouts ledger; assets register; monthly cost-allocation job |
| v2 | Upsell rules engine; multi-branch product schema; client portal |
