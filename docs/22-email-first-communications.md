# 22 — Email-First Communication System (WhatsApp deferred)

**Decision**: v1 talks to everyone by **email**. No WhatsApp, no send
APIs, no deliverability infrastructure. Emails are plain-text
conversation style — like you'd write them yourself — generated with
merge fields, copied and sent from your own mail client, logged in
`comms_log`. Channel column stays ready for future WhatsApp; nothing
else changes when it arrives.

---

## Mechanics (solo mode, doc 18, email channel)

1. **Template row** → code, stage, subject, body with merge fields
   (`{first_name}` `{company}` `{amount}` `{invoice_no}` `{due_date}`
   `{payment_link}` `{fee}` `{deadline}` …)
2. **Render** — app fills fields from the exact row (invoice snapshot,
   PO items, funding terms); body is **owner-editable** before sending
3. **Send** — copy body + open `mailto:` (subject pre-filled). Long
   bodies: clipboard, not mailto (mailto subject-only limit is honest)
4. **Log** — `comms_log` (channel=email, out, template code, snippet, at)
5. **Reply** — owner pastes the reply verbatim → flips the status the
   template's `expected_reply` names → **pending sequence cancels**

**The reply-cancels-pending rule**: any inbound reply from a contactable
cancels that contactable's queued outbox rows (except explicit ones like
monthly summaries). A conversation is never interrupted by a scheduled
nudge.

## The outbox (what makes the daily queue real)

`outbox` rows are the worklist: template + contactable + rendered
subject/body + `due_at`. Status: `scheduled → ready → sent | skipped`.
When a template is sent, its `followup_template_code` +
`followup_after_days` **auto-schedules the next step**. Sequences are
chains of templates, not a separate automation engine.

---

## 1. LEADS (new → contacted → demo_ready → demo_sent → proposal_sent → won | lost)

| # | Template | Trigger | Subject (example) | Expected reply → status flip |
|---|---|---|---|---|
| L1 | `lead_intro` | added to campaign | *"We build booking sites for {industry} — 10 days"* | interest → `contacted`; any reply cancels queue |
| L2 | `lead_followup_1` | L1 sent +3d, no reply | *"Re: your site — quick example"* | interest → `contacted` |
| L3 | `lead_followup_2` | L2 +7d | *"Free demo of what your site could look like"* | "send demo" → `demo_ready` |
| L4 | `lead_followup_3` | L3 +14d | *"Closing your file — last note"* | any reply revives; none → `lost (nurture)` |
| L5 | `demo_ready` | demo generated | *"Your demo is ready — {demo_link} (tap around, nothing real)"* | feedback → `demo_sent` |
| L6 | `demo_followup` | L5 +3d | *"What did you think? Questions?"* | questions → proposal queue |
| L7 | `proposal_send` | proposal built (snapshot) | *"Your quote: {amount} — {proposal_link} (valid to {valid_until})"* | "accepted" → `proposals.accepted` + `acceptance_channel=email` + pasted note |
| L8 | `proposal_followup` | L7 +4d | *"Any questions on the quote?"* | questions → negotiation notes |
| L9 | `proposal_reminder_expiry` | expiry −2d | *"Your quote expires {date} — want to hold the price?"* | accept/expire |
| L10 | `lead_won` | acceptance recorded | *"Welcome! Next: 5 quick questions about your business"* → chains into C2 | answers intake → `clients` + onboarding |
| L11 | `lead_lost_nurture` | closed lost | *"Understood — mind if I check back in 6 months?"* | nurture date set |

## 2. CLIENTS & DELIVERY (onboarding → build → review → deployed → maintaining)

| # | Template | Trigger | Subject | Expected reply → flip |
|---|---|---|---|---|
| C1 | `client_welcome` | win recorded | *"What happens next — and exactly what we need from you"* | — (chains C2) |
| C2 | `client_intake_request` | after welcome | *"5 questions so we build the right thing"* (the wizard, as email) | answers → project scope fields |
| C3 | `client_intake_reminder` | C2 +5d | *"Just the 5 answers whenever you have a minute"* | answers; 2nd silence → project `on_hold` |
| C4 | `milestone_update` | milestone due (weekly while building) | *"Progress: {done}. Next: {next}"* | — |
| C5 | `review_request` | build ready for first look | *"First look ready — reply OK or list changes"* | "OK" → review pass; changes → tickets |
| C6 | `review_reminder` | C5 +5d | *"Waiting on your OK to continue"* | same |
| C7 | `change_scope_note` | request outside scope | *"That's extra: included is X, the addition is {price} — approve?"* | approve → change proposal (snapshot) |
| C8 | `deployment_live` | targets healthy (doc 16) | *"Your app is live: {link} — check these 3 things"* | — (chains C9) |
| C9 | `acceptance_request` | C8 +1d | *"Reply 'accepted' and we'll send the invoice"* | "accepted" → `acceptance_channel=email`, invoice queued |
| C10 | `acceptance_reminder` | C9 +3d | *"One word and we're done: accepted?"* | same |
| C11 | `handover_guide` | acceptance + payment | *"How it works, your accounts, warranty — the keys"* (doc 15 offboarding-lite) | — |
| C12 | `maintenance_checkin` | quarterly | *"All monitored and healthy — anything bugging you?"* | issues → tickets |

## 3. INVOICING & PAYMENTS (client sub-flow)

| # | Template | Trigger | Subject | Expected reply → flip |
|---|---|---|---|---|
| P1 | `invoice_send` | invoice ready (snapshot price) | *"Invoice {invoice_no}: {amount} — link inside, due {due_date}"* | bank transfer → owner records `payment_confirmation=manual` |
| P2 | `invoice_reminder_1` | due date | *"Quick reminder: {invoice_no} due today"* | — |
| P3 | `invoice_reminder_2` | +7d overdue | *"{invoice_no} is now 7 days overdue"* | promise-to-pay → noted in comms_log |
| P4 | `invoice_reminder_3` | +14d firm | *"Final notice per our terms — service pause after {date}"* | pay/dispute → tickets/dispute flow |
| P5 | `payment_received_thanks` | payment confirmed | *"Received {amount} — thank you! Receipt attached"* | — |
| P6 | `subscription_renewal_notice` | Lane C, −10d | *"{product} renews {date} for {amount}"* | cancel → subscriptions paused |
| P7 | `receipt_request` | bank transfer claimed, unconfirmed | *"Can you send the transfer receipt?"* | receipt → payments row |

## 4. VENDORS (sourced → quoted → ordered → received → paid)

| # | Template | Trigger | Subject | Expected reply → flip |
|---|---|---|---|---|
| V1 | `vendor_intro` | first contact | *"We buy {category} regularly — send us your list"* | quotes → vendor record |
| V2 | `rfq_request` | PO draft needs prices | *"Quote request: {item list, qty}"* | quote → PO lines priced |
| V3 | `po_send` | PO approved + funded | *"Purchase order {po_no}: {items, totals}, deliver to {address} by {date}"* | ack → PO confirmed |
| V4 | `po_delivery_chase` | past `expected_at` | *"{po_no} was due {date} — status?"* | status → noted/delayed |
| V5 | `receipt_confirm` | PO marked received | *"Received {items} on {date} — receipt {receipt_ref} logged"* | — |
| V6 | `payment_remittance` | PO invoice paid | *"Payment {amount} sent for {po_no} — ref {ref}"* | — |
| V7 | `dispute_notice` | wrong item/qty/price | *"{po_no} line {n}: received X, ordered Y — correction please"* | resolution → PO updated |
| V8 | `rma_request` | faulty client device | *"RMA: {device, serial}, bought {date}, symptoms: {note}"* | RMA # → devices.status=rma |

## 5. INVESTORS (prospect → offered → committed → funded → returning → exited | defaulted)

| # | Template | Trigger | Subject | Expected reply → flip |
|---|---|---|---|---|
| I1 | `investor_intro` | relationship open | *"How we fund builds and returns work here"* | interest → investor prospect |
| I2 | `round_offer` | `project_funding` seeking | *"{project}: {target} needed, terms: {terms_summary}, deadline {date}"* | "in" → commitment |
| I3 | `round_followup` | I2 +5d | *"Any questions on the {project} round?"* | same |
| I4 | `commitment_confirm` | commitment recorded | *"You're in for {amount} — send to {iban}, ref {funding_ref}"* | transfer proof → awaiting funds |
| I5 | `funds_received_confirm` | funds landed | *"Received {amount} — procurement starts {date}"* | — |
| I6 | `investor_monthly` | monthly | *"{month}: {project status}, money in {x}, money out {y}, your position {z}"* (generated from rows) | questions → answered from rows |
| I7 | `payout_ready` | investor_payouts → payable | *"Your return of {amount} is queued — sending {date}"* | — |
| I8 | `payout_paid` | row marked paid | *"Sent {amount} — ref {ref}. Thank you!"* | — |
| I9 | `project_defaulted_notice` | doc 20 freeze | *"{project}: client defaulted — what we spent, salvaged, and your share"* | questions → answered from rows |
| I10 | `recovery_distribution` | each recovery event | *"Recovered {amount} from {source} — your share {share}"* | — |
| I11 | `salvage_round_offer` | doc 21 | *"New deal on the {project} assets — enhanced terms for you first"* | "in" → salvage round commitment |

## 6. TEAM (member → assigned → working → delivered → paid)

| # | Template | Trigger | Subject | Expected reply → flip |
|---|---|---|---|---|
| T1 | `team_intro` | onboarding a member | *"How we work: flat fee per deliverable, paid when the client pays"* (expectations set once, early) | ack |
| T2 | `assignment_brief` | module_order/PO assigned | *"{task}: scope, flat fee {fee}, due {deadline}, spec {link}"* (doc 14 build_spec / procurement list) | "accepted" → assignment acked |
| T3 | `assignment_ack_request` | T2 +2d no ack | *"Can you take this? If not, say so — no problem"* | decline → reassign (recorded) |
| T4 | `milestone_checkin` | +7d into work | *"How's {task}? Blockers?"* | blockers → tickets |
| T5 | `review_submission_request` | near deadline | *"{task} due {date} — submit via PR by then"* | PR → module_orders.pr_number |
| T6 | `payout_accrued_notice` | payout accrued (blocked) | *"Your {fee} for {task} is accrued — payable when the client pays (guard)"* | — |
| T7 | `payout_released` | payout marked paid | *"Paid {fee} — ref {ref}"* | — |
| T8 | `bonus_notice` | bonus row created | *"+{amount} bonus for {reason} — rides the same payment"* | — |
| T9 | `weekly_digest` | weekly | *"Your week: {payable} payable · {blocked} blocked · {new} new"* | — |

---

## The seven sequences (chains, auto-scheduled on send)

| Sequence | Chain |
|---|---|
| Cold lead | L1 →(+3) L2 →(+7) L3 →(+14) L4 → lost_nurture |
| Proposal | L7 →(+4) L8 →(expiry−2) L9 → expired |
| Delivery | C1 → C2 →(+5 if silent) C3 … C5 →(+5) C6 … C8 → C9 →(+3) C10 → C11 |
| Invoice | P1 →(due) P2 →(+7) P3 →(+14) P4 |
| Vendor PO | V2 → V3 →(late) V4 … V5 → V6 |
| Investor round | I2 →(+5) I3 → I4 → I5 → (monthly I6) → (I7 → I8 | I9 → I10…) |
| Team task | T2 →(+2) T3 →(+7) T4 … T6 → T7 (+T8) |

Every chain is **data**: `message_templates.followup_template_code` +
`followup_after_days`. Reordering or A/B-ing a sequence = updating rows.

## Tone rules (all templates)

Plain text, short paragraphs, **one ask per email**, no jargon anywhere
the client reads (doc 15 rule extends to all stakeholders), numbers
always match the snapshot rows, always a clear next step, never chase
twice in 48h.

## Schema deltas (v7)

- `message_templates` gains: `stakeholder`, `stage`, `trigger_note`,
  `expected_reply`, `followup_template_code`, `followup_after_days`
- `outbox` (contactable, template, rendered subject/body, `due_at`,
  status `scheduled|ready|sent|skipped`, `comms_log_id`,
  `cancelled_by`) — supersedes doc 18's "computed view" simplification
- Reply-cancels-pending and sequence scheduling are documented behavior
  of the send action, not background automation
