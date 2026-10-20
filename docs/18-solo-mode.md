# 18 — Solo Mode (owner-only operation, portals OFF)

## Premise

One user of the app: **the owner**. Investors, clients, team members,
branches — nobody logs in. The app is a private cockpit that *creates
artifacts* and *generates messages*; the human sends them on
WhatsApp/email and records what comes back. Every transaction happens
out-of-band; the app is the system of record, not the meeting place.

## Principle: solo-first, portal-optional

Every "portal feature" in this plan is two things:

1. **Tables + status columns** — always built (this repo's schema)
2. **A read-only view for outsiders** — not built in solo mode

Removing (2) changes nothing in (1). A portal can be added years later
as pure read-views — **no data migration, no new money logic, no fork**.

## What disappears

- Client portal, investor dashboard, team login — none exist
- External auth entirely: no invites, password resets, RBAC
  (single operator + local passcode/biometric)
- "Client clicks I accept" (doc 16 gate) → replaced by recorded reply
- Per-stakeholder hosting cost and attack surface — zero

## What replaces each portal touchpoint

| Portal design said | Solo mode does |
|---|---|
| Client opens invoice in portal | **Send invoice** → rendered message + payment link → WhatsApp/email; `comms_log` records sent-at |
| Client accepts deployment (click) | Owner sends "Your app is live ✓ — reply OK to accept"; records acceptance (`acceptance_channel = whatsapp`, snippet kept) |
| Payment webhook lights up portal | Tap/Moyasar webhook if configured, else owner clicks **Mark paid** (`payment_confirmation = webhook\|manual`) |
| Investor logs into dashboard | Generated monthly summary (message/email); owner sends; "notified" = a `comms_log` row |
| Team member checks payouts | Weekly digest per member, generated and sent; payout ledger unchanged |
| Branch managers enter data | WhatsApp/voice to owner → owner enters (or a form on *their own* Google/Formaloo account, doc 15) |

## The send pipeline (heart of solo mode)

1. **Template** — `message_templates`: channel, body with merge fields
   (`{client}` `{amount}` `{link}` `{due}`)
2. **Render** — app fills fields from the exact row (invoice snapshot
   price, proposal breakdown, deployment status)
3. **Deliver** — one click: copy rendered body to clipboard + open
   `mailto:` (subject pre-filled; **v1 = email only** — WhatsApp and any
   send API are deferred, see doc 22)
4. **Record** — `comms_log` row (out, template code, snippet, at) — the
   OS remembers what was said, so the owner answers from context
5. **Inbound** — owner pastes the reply (or voice-note summary) into the
   log and flips the status column

**Daily queue**: the dashboard computes *today's sends* — follow-ups due,
invoices ready, unpaid > 7 days, payout digests — as one worklist with a
Send button each. The owner works through it like inbox-zero; no
automation, no forgotten lead. (v2: made real by the `outbox` table and
sequence chains — doc 22.)

## Flow deltas (money logic unchanged)

- **Invoice**: create (snapshot price) → send (link) → paid (webhook or
  Mark paid) → blocked→payable payout guard fires exactly as designed
- **Proposal**: Quote engine → send summary + PDF → reply OK → owner
  records acceptance → convert (doc 05 transaction)
- **Deployment**: merge → deploy → healthy → send live message →
  acceptance recorded → invoice sent (doc 16 gate, human-recorded)
- **Investors**: capital in / dividends out stay in append-only ledgers;
  notification is a message, not a portal event
- **Offboarding**: doc 15 revoke-all checklist generated as a message to
  self; owner executes and checks off

## Schema deltas (v4)

- `message_templates` (code, channel, title, body, variables_json, active)
- `comms_log` (contactable_type/id, channel whatsapp|email|call,
  direction out|in, template_code, snippet, at)
- `invoices.payment_confirmation` — `webhook | manual`
- `proposals.acceptance_channel`, `proposals.acceptance_note`

## Honest tradeoffs

- **Owner is the bottleneck** for questions → every record shows the last
  message sent; answers take seconds from context
- **Transcription risk** on pasted replies → paste verbatim; only the
  status column is editorial
- **No "who viewed what" audit** → "sent at" *is* the audit; arguably
  enough at this scale
- **Forgetting is the main failure mode** → the daily queue + nag list
  replaces it structurally
- **Ceiling**: comfortable to ~30–50 active clients on WhatsApp; beyond
  that, switch on portal read-views (schema already supports them)

## Why this fits the plan's principles

Price snapshots, append-only ledgers, hour-based allocation, and the
blocked→payable payout guard **don't care who flips the columns**. Solo
mode removes *surfaces*, not *guarantees* — and it's the most secure
mode possible: no client passwords, no portal hosting, zero external
attack surface.
