# 23 — UI/UX Plan (the owner cockpit)

One user (you), one job: **work the queue, flip the columns, keep the
money honest**. Built with the plan's stack (React 19 + Vite 7 +
Tailwind 4 + TanStack Query) — implementable inside `zainpreneur-app`
(already has the catalogue/quote engine + offline lib) or as its own
app; this plan binds to neither.

---

## Design principles

1. **Queue-driven, not dashboard-y** — the home screen is a worklist to
   drain to zero, not charts to admire. No vanity metrics; every pixel
   serves a decision or an action.
2. **Plain language everywhere** — "money waiting on payment", never
   "accounts receivable". The doc-15 jargon rule applies to the owner
   UI too.
3. **Money honesty is visible** — snapshots ("priced 12 Mar —
   immutable"), guards ("blocked until INV-42 pays"), and cascades
   ("paying this unlocks 2 payouts") are *shown*, never implied.
4. **Mobile-first for five screens** — Today, Comms, Money, Clients,
   Scan. The rest is desktop-comfortable.
5. **One primary action per row** — every list row says what it wants
   next and offers exactly that button.

## Information architecture

**Desktop**: left sidebar + ⌘K command palette. **Mobile**: bottom bar
(Today · Comms · Money · Clients · More).

| Section | Screens | Docs it renders |
|---|---|---|
| **Today** | the queue (hero, below) | 18, 22 |
| **Sales** | leads kanban, lead 360, demo card, proposals board, **proposal builder** | 3, 4, 17 |
| **Projects** | projects list, **project 360**, module-order board, procurement/POs, deployment targets | 5, 11, 12, 14, 16 |
| **Money** | invoices, payment confirmations, **payouts board**, costs, reports (project P&L, waterfall) | 6, 7, 10, 13, 20 |
| **People** | investors, team, vendors (each: list + 360) | 7, 12, 13 |
| **Catalogue** | templates, variants & attributes, GitHub sync status | 2, 17 |
| **Infra** | client repos, credentials vault (masked + audit), client devices, agency assets | 8, 11, 15 |
| **Comms** | outbox, template library + editor, comms log | 18, 22 |
| **Settings** | passcode gate, profile/signature, cadences, invoice defaults, export | 18 |

## The hero screen: Today

```
┌─ Today · Tue 20 Oct ──────────────────────────── ⌘K ─┐
│ NEEDS YOUR REPLY (2)                                  │
│ ● Alnoor Hotel — replied to proposal "POS setup"      │
│   [Paste reply]                                       │
│ SEND TODAY (5)                                        │
│ ✉ Proposal follow-up → Aqua Pets (due)    [Copy+Send] │
│ ✉ Invoice INV-42 reminder → Carwash Co    [Copy+Send] │
│ MONEY (2)                                             │
│ ⚠ INV-38 unpaid 9 days — Aqua Pets        [Remind]   │
│ ● Bank transfer claimed $2,000 — confirm?  [Confirm]  │
│ BLOCKERS (1)                                          │
│ ● PO-7 stuck at ordered (chase vendor Al-Rashid)      │
│ THIS WEEK (3)                                         │
│ · Subscription renewal $15 — Aqua Pets (Thu)          │
│ · Demo link expires — Gulf Spa (Fri)                  │
└───────────────────────────────────────────────────────┘
```

Sections: **Needs reply** (paste-reply flow) → **Send today** (outbox
ready) → **Money** (ready invoices, >7d nags, unconfirmed transfers) →
**Blockers** (stuck POs, `pending_agent` deploys, reviews awaiting
client) → **This week** (renewals, expiries, scheduled digests).
Drain-to-zero with a quiet "all clear" state.

## Signature interactions (the patterns that make this app itself)

1. **Cascade preview** — before any money confirmation, show the unlock
   chain: *"Marking INV-42 paid ($5,000) will make payable: Payout #9
   ($500, Omar) · Investor payout #3 ($3,000, Ahmed)."* Confirm once,
   cascade fires, snackbar offers Undo.
2. **Guard badges** — blocked rows show *why* in plain words, clickable:
   `gray chip: "waiting on INV-42"` → jumps to the invoice. The
   blocked→payable philosophy rendered as a UI component.
3. **Send modal** (every outbound email) — rendered subject + body,
   editable, *Copy body* + *Open mail* (mailto, subject pre-filled),
   then **Mark sent** → comms_log row + follow-up auto-scheduled.
4. **Paste-reply modal** — paste verbatim → pick the expected flip from
   the template's `expected_reply` (pre-selected) → logs + flips the
   column + cancels that contactable's pending nudges.
5. **Snapshot badges** — every price object carries `priced 12 Mar ·
   immutable`; edits require a change-order flow, so the badge never
   lies.
6. **⌘K palette** — actions first ("new lead", "mark paid", "send
   invoice"), then fuzzy search across leads/clients/invoices/POs.
7. **Scan button** (mobile) — camera → receipt photo → attach to the
   open PO (doc 19 step S8, ten seconds on-site).

## Key screens (beyond Today)

**Proposal builder** (doc 17 engine as UI): pick service → tap attribute
pills (pages, language, WhatsApp button…) → live price breakdown lines
(base + extras − discount) with margin shown to you only → **Snapshot &
send** → renders template L7 → Send modal → proposals row frozen.

**Project 360** — tabs: *Overview* (health, next action, contact quick-
actions) · *Build* (module-order board, PR links, deployment cards with
status + one-button rollback, POs with funded-by badge: `investor
advance ▸` vs `own cash`) · *Money* (invoice, payouts, P&L incl. the
waterfall visual for investor deals) · *Comms* (timeline from
comms_log) · *Assets* (devices, serials, warranty).

**Payouts board** — columns `accrued → blocked → payable → paid`;
blocked rows carry the guard chip; **Release** on payable rows triggers
the cascade confirm. Team fees and investor payouts share the board
with a kind filter.

**Investor 360** — capital in, returns paid, position across rounds,
funding rounds (incl. `salvage_round` lineage), and one-click
generation of I6/I7/I9/I10 templates filled from their rows.

## Visual system

- **Tailwind 4 tokens**; light default + dark; calm, dense, table-first
  for money, cards for people.
- **Semantics, reused everywhere**: green = paid/live/healthy · amber =
  your action needed · red = overdue/defaulted · blue = in progress ·
  **gray = blocked-by-guard** (with the why-chip). One `StatusChip`
  component maps every schema enum to a label + color — statuses can
  never drift from the DDL.
- **Tabular numerals for all money**; amounts always with currency;
  right-aligned in tables.
- **Empty states teach**: *"No leads yet — paste the contact from your
  chat and log where they came from."*

## Component inventory (build once, use everywhere)

`StatusChip` · `MoneyRow` (amount · snapshot badge · guard note) ·
`CascadeConfirm` · `SendEmailModal` · `PasteReplyModal` · `QueueItem` ·
`PipelineBoard` (kanban over any stage enum) · `DataTable` (filter by
status, sort, bulk-select for sends) · `Timeline` (comms_log per
contactable) · `ReceiptUploader` · `GuardNote` · `CommandPalette` ·
`Waterfall` (tier bars for investor deals, docs 19–21).

## What is deliberately NOT built

No portals or share links · no roles/invites · no notification system
outbound (the queue is the notification) · no charts that don't drive
an action · no settings screen deeper than one page.

## Build order (maps to the delivery roadmap)

| Phase | Screens |
|---|---|
| **A — MVP** | passcode gate + settings · Today (reply/send/money) · leads kanban + lead 360 · proposal builder · clients & projects basic · invoices + payments + mark-paid cascade · Comms (outbox, template library, paste-reply) |
| **B** | payouts board full · procurement/POs + receipt scan · deployment targets + rollback · module-order board · investors 360 + funding rounds · vault UI (masked, rotate, audit) · client devices & assets |
| **C** | reports (project P&L, waterfall, margins) · cost allocation views · multi-branch · default/salvage workflow screens (docs 20–21) · ⌘K palette · RTL/Arabic client-facing artifacts · offline hardening |

## Schema delta (v8, tiny)

`app_settings` (key/value): owner name + email + signature, invoice
due-days, default follow-up cadences, timezone, theme, gate on/off.
UI state that must survive a device change; everything else is
preference-local.
