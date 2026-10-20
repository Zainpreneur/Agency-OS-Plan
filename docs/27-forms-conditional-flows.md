# 27 — Forms, Conditional Logic & Flows

Every form in the app, their fields, the conditions that show/hide/
require them, validation, and what each submit *does* to the workflows.
Solo mode: all forms are yours; "client forms" here mean the
questionnaire rendered into an email (doc 22, C2) — no portals.

---

## Form architecture

- **Field vocabulary**: text · email · phone · number · **money**
  (currency-aware, stored minor-units) · date · select · **pills** ·
  multi-checkbox · switch · textarea · **relationship picker**
  (searchable + "create new inline") · **photo/file upload** ·
  derived-readonly (computed, shows its math on hover)
- **Validation tiers**: (1) field-level **Zod** — same schema runs in
  the form and on the Hono server, inline errors; (2) cross-field
  (discount > 0 ⇒ reason required); (3) business rules re-enforced
  server-side (deposit gate); (4) irreversible actions get a **cascade
  preview** confirm. **Typed data is never lost** on any error.
- **Drafts autosave locally** (offline lib) — a form started on-site
  survives dead wifi and app restarts.
- **Smart prefill**: every form opened from a context prefills that
  context (PO from a project → project bound; invoice from acceptance →
  client + snapshot amount prefilled).
- **One-transaction submits**: multi-step wizard = one server call at
  the end (proposal builder writes proposal + lines + outbox + event
  atomically). Back navigation never loses answers.

## Conditional rules engine

Declarative `when` rules co-located with each form's Zod schema
(testable in Vitest):

```
{ field: 'funding_source', is: 'investor_advance',
  show: ['funding_round_id'], require_unless: 'deposit_gate_waiver' }
```

Per-field: `show` · `require` · `default_if` · `options_from` ·
`disable`. **Two condition systems, cleanly separated**: catalogue
*exclusions* (attribute combos the Quote engine forbids — doc 17) live
in data; app-form conditions live in code next to their schema.
Conditions re-evaluate live; hiding a field nulls its value silently
(shown as a strikethrough chip, so nothing vanishes unseen).

## Form inventory

| Form | Steps | Heavy conditions | Submit side effects |
|---|---|---|---|
| **New lead** (quick capture) | 1 | has_website=no → upsell flag; add-to-campaign switch → campaign + sequence picker + follow-up default | lead + comms seed + targets enrolled |
| **Proposal builder** | 5-wizard | the big one (below) | proposal + lines + L7 outbox + event |
| **Invoice create** | 1 | source=proposal → snapshot lines readonly; bank transfer → P7 scheduled; vat switch → computed line | invoice + lines + P1 outbox |
| **Purchase order** | 1 | investor advance → round picker + **deposit check → waiver note required**; new vendor inline mini-form; assigned_to → T2 preview | PO + items (+ T2 outbox) |
| **Mark paid** | 1 | partial amount → balance note; bank → ref + receipt upload | payments row + **cascade** + P5 |
| **Paste reply** | 1 (micro) | expected flip pre-selected; receipt attached → file upload | comms in + flip + queue cancel |
| **Funding round** | 1 | rule type: fixed→return amt · multiple→×number · share→%; salvage switch → defaults offer list to prior investors | round + I2 per investor |
| **Deploy target** | 1 | provider: vercel→token+project id · ssh→key+build cmd · office→agent install card + `pending_agent` | target row (+ agent checklist) |
| **Credential add** | 1 | provider: google→OAuth button · api services→key field · vps→key upload; expiry date → rotation reminder scheduled | vault row (masked forever) + audit |
| **Device register** | 1 | kind: sensor→firmware · terminal→serial+warranty; photo **required** | device + PO provenance link |
| **Campaign create** | 2 | channel per step → step fields (email→template; call→script note) | campaign + sequence_steps |
| **Assignment** (team) | 1 | comp plan: flat→amount · share→% · support→monthly (**hourly rejected by schema**) | payout accrual + T2 outbox |
| **Intake questionnaire** | 1 (email-rendered) | Q3 multi-checkbox → Q4 "which matters most" appears | intake_responses + scope fields |
| Intake reminder, investor add, vendor add, team add, settings | 1 each | minor | rows |

## The heavyweight forms, in detail

### Proposal builder (5 steps — the app's flagship conditional form)

1. **For whom** — lead/client relationship picker (search + inline create)
2. **Service** — catalogue gallery pick
3. **Configure** — *the* conditional surface: **variant pills first**
   (Basic/Standard/Premium) → selection filters which **attributes**
   render (pills/color/checkbox per `displayType`) → live `priceExtra`
   additions → catalogue **exclusions disable incompatible combos in
   real time** (greyed with the reason, not hidden) → ConfigurationRules
   (number+unit, per_selection/per_unit math) → custom values allowed
   where the attribute permits
4. **Adjust** — discount (number; >0 ⇒ reason required) · maintenance
   switch (→ subscription preview line) · multi-branch switch (→ branch
   count → per-branch line) · delivery-days computed from variant
5. **Review** — full breakdown (base + variant + attributes + config +
   add-ons − discount), **margin visible to you only**, valid-until
   date (default +14d) → *Snapshot & send* → renders L7 → Send modal

Submit: proposal + proposal_lines (snapshots frozen) + outbox row +
status event, **one transaction**.

### Purchase order (where doc 20's gates live in the UI)

project picker → kind pills → vendor picker (*create new inline*: name,
category, contact) → items repeater (description, qty, unit_cost →
derived total) → **funding pills**: own cash | investor advance →
advance shows the round picker and checks for a client deposit — **no
deposit ⇒ waiver note textarea becomes required** (audited, doc 20
gate #1) → assignee picker (→ T2 brief preview with rendered item
list) → expected date → address (prefilled from client).

### Mark paid (the cascade moment)

amount (prefilled, editable → partial ⇒ balance note recorded) · date ·
provider pills (tap|moyasar|bank → bank adds reference + receipt
upload) → **cascade preview panel**: "this makes payable: Payout #9 ·
Investor payout #3" → confirm → payments row + flips + P5 thanks
scheduled.

### Intake questionnaire (a form rendered *into* an email, C2)

Five plain questions, no jargon: *What do you sell?* · *Who are your
customers?* · *What should customers do online?* (book/order/pay/see
prices/contact/track) → **if any selected** → *Which matters most?*
(pills) · *Anything else?* Reply-pasted answers → `intake_responses`
(row keeps the raw answers verbatim) + project scope fields.

## Full CRUD matrix (doc 27, v12)

Doc 23 froze the seven *views*; this section freezes the *actions*. Every
entity is creatable, editable and removable from the UI — not just
readable. Three shared pieces carry the whole surface:

- **`FormModal`** — a field-descriptor list in, a values record out. ~25
  forms are one component plus a `FieldDef[]` array. Validation is
  field-level (required, email/number/date, min) and the same component
  renders business-rule errors returned by the store *in place* — typed
  data is never lost on any error (the form architecture rule above).
- **`ConfirmModal`** — a danger confirm that surfaces the guard reason
  inline. A refused delete shows *why* (and what to do instead), never a
  silent no-op.
- **`RowActions`** — the `✎` / `✕` pair on every table row, card, gallery
  tile and detail modal, so the affordance is in the same place everywhere.

Create and every status transition write an **append-only status event**.
Money rows are **never erased**: they void or cancel. Where a row is
referenced by another row's history, the store **archives instead of
deleting** and refuses the hard delete with a reason.

| Entity | Create | Edit | Remove | Write guard (surfaced as an error) |
|---|---|---|---|---|
| **Lead** | quick-capture form | full form | **Archive** | archiving cancels pending sends; won/lost keep their reason |
| **Client** | client form | client form | **Archive** | blocked while any invoice is open — settle or void first |
| **Vendor** | vendor form | vendor form | Archive · Delete | hard delete blocked when POs reference it → archive (keeps cost trail) |
| **Team member** | team form | team form | Archive · Delete | hard delete blocked when payout rows exist → archive |
| **Investor** | investor form | investor form | Delete | blocked while capital is deployed — settle the position first |
| **Funding round** | round form (rule branch) | round form | Delete | blocked once `raised > 0` — close the round instead |
| **Project** | project form | project form | Delete | blocked when POs point at it — move to `delivered` |
| **Purchase order** | PO form (item repeater) | PO form | Delete | `draft` only — once ordered the cost is settled, never erased |
| **Invoice** | invoice form (snapshot source) | **draft only** | Void · Delete draft | paid rows never move; sent rows void (number stays in the books) |
| **Payout** | ad-hoc payout form | — (append-only) | **Cancel** | paid rows never move — money history is append-only |
| **Template** (comms) | template form | template form | Delete | blocked while any outbox row is queued to it |
| **Campaign** | 2-step campaign form | campaign form | Delete | active campaigns must pause first (enrolled leads) |
| **Catalogue template** | catalogue form | catalogue form | Delete | proposals keep their frozen price snapshots |
| **Deploy target** | deploy form (provider branch) | deploy form | Delete | tracking row only — infrastructure teardown is manual |
| **Credential** | credential form (provider branch) | credential form | Delete | masked pointer only — rotate the real key with the provider |
| **Device** | device form (kind branch, photo) | device form | Delete | PO provenance stays — the PO still shows what was bought |

**PO advance** is the one status chain exposed as a button rather than a
form: `draft → ordered → received → installed → invoiced`. Each press
writes its event and the next label follows from the state. **Invoice
`nextInvoiceNo`** is computed from the highest number on record — deleting
a draft never reuses a number that was ever issued.

Reactivating an archived row is just an **edit** back to `active` — no
separate restore verb, one code path, one audit trail.

## Form → workflow mapping

Every submit names the workflow step it advances (doc 26): lead form →
W1 start · proposal builder → W1/W2/W3 quote step · invoice → W1 money
spine · PO → W4/W9 · mark paid → cascade (W1/W4/W6 endings) · funding
round → W6 · intake → W1 delivery start · deploy target → W15.

## Micro-interaction rules

Money inputs are currency-aware and store minor units · relationship
pickers always offer inline create (never a dead-end "not found") ·
computed fields show the formula · selects use pills when ≤5 options ·
every irreversible submit previews its consequences first · mobile:
one question per screen in wizards, big tap targets, camera input for
receipts/photos wired straight to uploads.

## Schema delta

**v12** — two lifecycle columns so the archive-not-delete rule is data,
not code:

- `vendors.status` (`active|archived`) — new; lets a vendor referenced by
  POs be retired without deleting the cost trail.
- `team_members.status` — already present (`active|offboarded`); the
  offboarded value *is* the archive flag, documented here so code and
  docs agree.
- `leads.status` already includes `archived` (doc 26); `clients.status`
  already carries the archive state (doc 5). No other new columns: every
  action in the matrix above is code over columns that already exist.

The **reference frontend** (`Zainpreneur/agency-cockpit`) implements this
matrix against an in-memory store — `src/lib/store.ts` is the single swap
point, so when the Hono API lands its actions become HTTP calls and its
`ActionResult` guard errors become server responses, with no component
changes.

**v11** — `intake_responses` (client_id, project_id, answers_json
verbatim, received_at): the raw questionnaire answers stay auditable next
to the scope fields they populate.
