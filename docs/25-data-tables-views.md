# 25 — Data Tables, Fields & Views (the full map)

Every entity in the schema, the fields each view shows, and which view
type fits: **table · list · board · card · timeline · gallery ·
detail/360** (+ a calendar overlay). This is the contract between the
DDL and the UI components from doc 23.

---

## View vocabulary

| View | Use when | Superpowers |
|---|---|---|
| **Table** | dense records, money, comparison | sort, filter, group, bulk-select (for sends), CSV export |
| **List** | simple rows, one status + one action | fast scanning, swipe actions (mobile) |
| **Board** | anything with a pipeline status | drag = status flip (cascades fire on drop), column counts |
| **Card** | decision objects (3–5 facts + one action) | Today queue, deployment targets |
| **Timeline** | "what happened here, in order" | comms + status changes + payments merged chronologically |
| **Gallery** | visual objects | images with facts; tap → detail |
| **Detail/360** | one entity, everything about it | tabs; the destination every row opens into |
| **Calendar** | the `due_at` family | one month grid: follow-ups, expiries, renewals, credential expiry — colored by entity |

**Construction rules** (from doc 23, restated as law): one primary
action per row · StatusChip maps every enum · money columns tabular,
right-aligned, snapshot-badged · filters persist per view · every view
drills to detail · empty states teach the next action · board drag and
bulk-send are the only "power" gestures.

---

## SALES

| Entity | List/Table columns | Detail header | Views (primary → secondary) | Filters / grouping | Primary action |
|---|---|---|---|---|---|
| **Leads** | business, contact, source, industry·city, status, next-follow-up | all fields + touches + has_website | **Board** (status) → Table (bulk campaign-add) → **Timeline** (lead_activities + comms_log) | status, industry, source, has_website | paste reply / queue email |
| **Campaigns** | name, kind, focus, A/B variant, budget/spend, status | + sequence steps + funnel | **Table** → Card summary | kind, status | start/pause |
| **Demos** | template, for whom, status, views, expires | links, view history | **Gallery** (thumb, facts) → Table | status, expiring | copy link / send L5 |
| **Proposals** | no, for whom, list→offered, status, valid-until | lines, snapshot badge, comms, cascade | **Board** (draft→sent→viewed→decided) → Table | status, expiring ≤7d | send / follow-up / record acceptance |

## DELIVERY

| Entity | List columns | Detail | Views | Filters / grouping | Action |
|---|---|---|---|---|---|
| **Clients** | name, contact, created | **360**: Overview·Money·Comms·Assets | **Table** → 360 | — | open 360 |
| **Projects** | name, client, kind, status, next-action | **360** (doc 23) | **360** → Board (status) | status, kind | open 360 |
| **Tickets** | subject, client, priority, age | thread | **List** | priority, open | convert → module order |
| **Module orders** | name, client, price, fee, assignee, status, PR | build spec, PR link | **Board** (requested→…→invoiced) → Table | assignee, stuck | assign / send T2 |
| **Purchase orders** | no, vendor, total, **funded-by badge**, assignee, status, receipt? | items, vendor, timeline | **Table** (stuck-first) → Gallery (receipts) | status, funded-by, stuck >5d | send V3 / chase / upload receipt |
| **Deploy targets** | repo, provider, env, status, last deploy, sha | env var names, logs | **Card grid** → Table | provider, degraded | deploy / **rollback** |
| **Update PRs** | repo, kind, title, age, status | diff link | **List** | behind-by > 2 | open/merge |

## MONEY

| Entity | List columns | Detail | Views | Filters | Action |
|---|---|---|---|---|---|
| **Invoices** | no, client, total, status, due | lines, snapshot badge, payments, cascade preview | **Table** (overdue-first, aging sort) → Card in Today | status, aging bucket | send P1 / **mark paid** |
| **Payments** | invoice, provider, amount, at | — | read-only Table | provider | — |
| **Payouts** | who, kind, amount, status, guard chip | why-blocked, release history | **Board** (accrued→blocked→payable→paid) → Table | team/investor, client, kind | **release** (cascade) |
| **Expenses / tool charges** | date, category, amount, allocation | receipt | Table | category, month | add |
| **Funding rounds** | project, target, status, source-kind (salvage?) | terms snapshot, agreement, waterfall | Table → detail | status, salvage | send I2 |
| **Investor payouts** | investor, round, amount, tier, status, trigger | trigger payment link | Board (with payouts) → Table | status | release |

## PEOPLE

| Entity | List columns | Detail | Views | Action |
|---|---|---|---|---|
| **Investors** | name, deployed, returned, position, concentration | **360**: rounds, positions, comms, statements | **Table** → Card grid → 360 | send I6/I7/I9 |
| **Team** | name, comp plan, pending, paid-YTD, on-time % | assignments, payouts, reliability | **Table** → 360 | assign task |
| **Vendors** | name, category, POs, on-time %, disputes | quotes, POs, price variance | **Table** → Gallery (logo) | send RFQ |

## CATALOGUE & INFRA

| Entity | List columns | Detail | Views | Action |
|---|---|---|---|---|
| **Templates** | image, name, from-price, sold, latest tag, behind-count | variants + attributes (pills editor), sync status | **Gallery** → Table | edit / sync |
| **Client repos** | repo, client, live tag, behind-by | PRs, deploys | Table | open updates |
| **Credentials** | provider, kind, scopes, expires, status (**masked — never plaintext**) | rotation history | Table → Timeline (audit_log) | rotate / revoke |
| **Client devices** | photo, kind, serial, warranty-until, status | PO provenance | **Gallery** → Table | RMA |
| **Agency assets** | photo, tag, holder, condition | history | **Gallery** → Table | reassign |
| **Outbox** | who, template, due, status | rendered email | **List** (grouped: today/this week/sent/skipped) → Table | copy+send |
| **Comms templates** | code, stakeholder, stage, chain | editor + preview w/ sample data | List → editor | edit |
| **Comms log** | who, channel, dir, snippet, at | — | **Timeline** per contactable → global Table search | paste reply |

---

## Timeline design (the one real schema gap, fixed in v10)

Timelines are an **event union per entity**:

| Entity | Event sources |
|---|---|
| Lead | `lead_activities` (already append-only, doc 3) ∪ `comms_log` ∪ demo/proposal events |
| Client / Project | **`status_events`** ∪ comms_log ∪ module/PO/deploy timestamps |
| Invoice | `status_events` ∪ `payments` ∪ comms_log (sends/reminders) |
| Credential | `audit_log` only |
| Payout | `status_events` (accrued→…→paid) ∪ trigger payment |

New `status_events` (entity, entity_id, from_status, to_status, at,
note) — written by the **same code path that flips any status column**,
so the timeline can never drift from reality. One table completes six
entities' histories.

## Gallery design

Image fields: `templates.image_url` · `assets.image_url` ·
`client_devices.image_url` · demos use a derived thumbnail of
`github_pages_url` (nullable) · PO receipts already have `receipt_url`
(doc 19). Fallback placeholder = colored initials card (never a broken
image). Aspect ratios fixed per gallery (16:9 templates, 4:3 devices),
lazy-loaded, cached by the offline lib for site visits.

## Board definitions (drag = status flip, cascades on drop)

| Board | Column field → order | Note |
|---|---|---|
| Leads | `leads.status`: discovered→contacted→demo_built→demo_shared→proposal_sent→negotiating→won/lost | drop to won runs doc 5 conversion |
| Proposals | `proposals.status` | drop to accepted asks for the pasted reply first |
| Module orders | `module_orders.status` (8 cols, collapse last 3) | drop to deployed schedules deploy |
| Payouts | `payouts.status` | drop to payable impossible — **guard decides**, not drag |

## Calendar overlay

One month grid over the due_at family: `next_follow_up_at` ·
`proposals.valid_until` · `invoices.due_at` · `demos.expires_at` ·
subscription renewals · `credentials.expires_at` · PO expected dates.
Colored by entity; clicking an entry opens the row. No separate events
table — due dates already exist everywhere.

## Schema delta (v10)

- `status_events` (entity, entity_id, from_status, to_status, at, note)
  — written on every status flip; timeline source for six entities
- `templates.image_url` · `assets.image_url` · `client_devices.image_url`
  (galleries); demo thumbnails derived
