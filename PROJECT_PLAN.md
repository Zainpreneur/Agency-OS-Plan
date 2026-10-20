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

## 12. Code & Client Repos (doc 11)

Client code lives in **one private repo per client** (`client-alnoor-website`),
created at conversion. Protected `main`, staging `develop`, deploy = tag
(`v1.4` = what's live, a git fact). Updates flow: ticket → (change request →
mini-proposal) → branch → PR → merge = deploy → client pinged. Maintenance
clients get **ready-to-merge update PRs** when the upstream template improves
— churn defense with zero extra labor.

## 13. Custom Projects & Procurement (doc 12)

`full_build` projects enforce a **budget breakdown** at creation (hardware
15k / team 10k / other 5k against a 50k contract). Hardware goes through
`purchase_orders` → `client_devices` (serials, firmware, RMA — distinct from
our own asset register). Live margin: contract vs spent vs committed vs
accrued payouts, visible daily.

## 14. Investors & Funding (doc 13)

Big builds can be funded by investors: `project_funding` round →
`investments` with **snapshotted promised returns** → funds tracked as
project-restricted cash, never mixed with ops. On the closing client
payment, the `funding_waterfalls` distribute (3 × 15k = 45k to investors,
5k residual to agency) via `investor_payouts` with the same
**blocked-until-client-pays** guard the team uses. Investor portal + auto
statements.

## 15. Module Add-ons — AI-assisted builds (doc 14)

Existing client asks for more capability ("POS + HR module?") → ticket →
mini-proposal (3k, snapshot) → `module_order` with a **flat team fee** (500,
not hourly/monthly) → platform renders a **build spec** (scope + client
stack + brand tokens) → team member opens the repo in OpenCode/Claude Code,
builds, PRs, merges → deploy = tag → invoice → payout accrues on payment,
blocked until paid. The AI tool varies; the spec doesn't. Dogfood note:
this is the same loop that builds Agency OS itself — *build for yourself
before you build for others*.

---

## 16. Integrations & Credential Vault (doc 15)

**"Client owns the world, you hold the keys."** Every account, subscription,
and card is created under the *client's* identity (provisioned via *their*
Google OAuth); the agency's cards never touch a client project. What the
agency holds is encrypted (AES-256-GCM vault, key from env, every secret
READ audited), scoped, and revocable. A connector layer (Airtable → tables,
Formaloo → forms, WhatsApp Cloud API → messaging) hides all of this behind
plain language, with health-checks that auto-ticket a broken token before
the client notices.

Three money lanes: **(A)** client → agency (dev fee on deployment
acceptance, hardware pass-through at PO price), **(B)** client → providers
directly on their own card — *tracked* in `external_client_costs`, never
billed and never mixed into margin reports, **(C)** client → agency for the
agency's own SaaS (subscriptions engine). Card numbers are never stored
(PCI). Code repos default to agency-held with a `repo_policy` that flips on
final payment — data and accounts are unconditionally the client's.
Offboarding is a revoke-all checklist because everything vault-references
its credentials.

---

## 17. Deployment Matrix (doc 16)

One pipeline, four adapters: **Vercel** (API token), **Hostinger VPS**
(SSH + build script), **generic PaaS** (deploy hook), **office VPS**
(**pull-agent** — their box polls for releases, no inbound firewall holes;
`pending_agent` status when offline). Uniform contract:
`deploy(sha) / rollback() / healthcheck() / logs()`; merge → deploy →
health check → `current_sha` updated → portal flips to *"Your app is live ✓"*
in non-technical language. Every provider gets a one-button rollback.
Payment gate: all production targets healthy + explicit client acceptance
click → invoice(s) at snapshot price → payment webhook → maintenance mode.

---

## 18. Reusing zainpreneur-app's Service Schema (doc 17)

`zainpreneur-app` already ships a complete configuration-pricing engine
(AttributeRecord → AttributeValue with `priceExtra` → Variant with
price/cost/margin → Quote breakdown → RequestSnapshot freeze, already used
by its LeadProposal). Agency OS reuses it instead of reinventing it, under
one rule:

> If the client chooses it and it changes the price → attribute/value.
> If it's an event or money movement → a plain typed column. Never the reverse.

**Required** in: proposal/quoting (price computes itself line by line —
the "client sees *why* 3,000" requirement), module add-on quoting (config
selections render the build spec), the client portal intake (the existing
`ServiceRequestWizard` with pill/color pickers = zero jargon), delivery
(ServiceRequest's branch scope, effort tracking, snapshot — already built
and tested). **Helpful** in: template catalogues (variants carry cost and
margin *before* quoting) and demo configuration. **Forbidden** in every
ledger: payouts, expenses, payments, investments, assets, credentials,
campaign targets — immutable rows only. A reused quote configuration can
crystallize into a named variant (`generation: 'dynamically'`) — quoted
configs become catalogue products.

---

## 19. Solo Mode — owner-only operation (doc 18)

The owner is the app's only user; no client portal, no investor
dashboard, no team login. The app *creates artifacts and generates
messages* (template → merge fields → one-click WhatsApp `wa.me` link /
`mailto` → logged in `comms_log`); the human sends them and pastes
replies back, flipping status columns. Payment: webhook if configured,
otherwise **Mark paid** (`payment_confirmation = webhook|manual`).
Deployment acceptance and investor notification become recorded replies,
not portal clicks. A computed **daily queue** (follow-ups due, invoices
ready, unpaid > 7 days, digests) replaces automation — the main failure
mode at this scale is forgetting, not tooling. Portals were always just
read-views over these tables: solo mode doesn't build them, and adding
them later needs no data migration. Ceiling ≈ 30–50 active clients;
beyond that, switch views on.

---

## 20. Worked example: the POS + hardware deal (doc 19)

The acceptance test tying docs 12–14+18 together, traced row-by-row:
WhatsApp request → `comms_log` → draft `purchase_orders`/`purchase_items`
(vendor × price per item) → investor funds procurement via
`project_funding`/`investments` (2,000, fixed 3,000 return) → PO bound to
the restricted pot and an assigned team member → 10,000 proposal sent as
a WhatsApp message, acceptance recorded as the client's reply →
procurement-instruction message to the team member → receipts flip the
PO to received → invoice at snapshot price → payment fires the guards:
**two** `investor_payouts` rows (principal first, upside *after* the
team fee) + the flat-fee `payouts` row. Result: investor 3,000, team
2,000, agency 5,000, agency cash outlay 0. Schema gap fixed by the
walkthrough: POs gained `funding_id`, `assigned_team_member_id`,
`receipt_url`. Partial-payment behavior is tiered, not pro-rata —
rehearsed failure modes are listed in the doc.

---

## 21. Loss & default waterfall — the mirror image (doc 20)

The 30k-deal/20k-cost/2-investors/client-vanishes scenario, reasoned
through: the blocked→payable guards mean the 10k team fee and the 26k
investor returns **never unlock** without the client payment — actual
cash at risk is the 10k of servers, against a still-segregated 10k pot.
Default protocol: freeze (`defaulted`, `uncollectible`, upside rows
`cancelled`) → liquidate (unspent pot + `asset_dispositions`: return /
resell / repurpose servers; code becomes internal IP) → **recovery
waterfall mirroring the profit tiers** — investor *capital* pro-rata
first, optional team goodwill from agency pocket or strictly after
investors, agency absorbs the remainder → realized loss computed per
investor (`amount − Σ recovery_distributions`), never negotiated from
memory. The refund challenge is answered by the funding-time contract
snapshot and the trigger design: guaranteed returns would be a *loan*,
enforced at data entry. Six prevention gates close the loop:
deposit-before-procure (audited waiver column), milestone buying,
concentration caps, margin sanity, guaranteed-return-is-debt, and a
client-vanish nag list while assets are still returnable.

---

## 22. The salvage play — dead deal into next deal (doc 21)

The defaulted hotel deal left three surviving assets — 50 contacts, the
built code, the servers — and the platform converts each: the contacts
become a hotel-vertical campaign (30 pitched, 1 accepted at 60,000, 3.3%
on a warm list), the code is born as an **internal template** quoted via
the Quote engine, and the servers are **repurposed at 9,000 book value**
into the new project (`asset_dispositions`), settling the dead
project's recovery pot (4.5k per investor, closing the old 500 loss as
documented history). The new funding round is tagged `salvage_round`
and offered first to the burned investors with **enhanced, still
trigger-bound** terms (15k back on 10k in — the extra value, justified
by the de-risked IP). The team's cancelled old fee is honored by
riding the new deal as flat `delivery` 10k + `bonus` 2k rows — the
blocked→payable guard is never broken. The 60k waterfall: recovery 9k →
team 12k → investor principal 20k → enhanced upside 10k → agency margin
**9k**, plus the template IP and 49 warmed leads. Whole seam costs
schema v6: two columns on `project_funding` and one
`recovery_distributions` source code.

---

## Delivery order (MVP → v2)

| Phase | Scope |
|---|---|
| Week 1 | GitHub sync → Catalogue; Clients + Sales; invoice PDF + payment link |
| Week 2 | Lead intake; campaign sender + short links; demo builder |
| Week 3 | Proposals (snapshot pricing); convert-to-client transaction |
| Week 4 | Payouts ledger; assets register; monthly cost-allocation job |
| v2 | Upsell rules engine; multi-branch product schema; client portal |
| v2.5 | Client repos & update PRs; investors & funding; module add-on engine |
