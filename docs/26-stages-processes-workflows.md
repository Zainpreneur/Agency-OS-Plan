# 26 — Stages, Processes & Workflows (the complete state machines)

Every lifecycle in the app, every transition rule, every guard, and the
end-to-end workflows that weave them together. Pure process — schema v10
already supports all of it.

---

## Universal transition rules (law)

1. **Single write path** — every status change flows through one code
   action (`flip(entity, to, note)`); it writes the column **and** the
   `status_events` row atomically. Timelines can't drift.
2. **Four actors** may flip columns:

   | Actor | Flips | Evidence |
   |---|---|---|
   | Owner (UI) | everything except money facts | click, drag (where allowed), paste-reply |
   | Webhooks (Tap/Moyasar) | `invoices → paid`, payments rows | provider external_id |
   | GitHub (webhooks) | update PRs, deploy health, template sync | delivery_id, idempotent inbox |
   | Cron | overdue invoices, expiring demos/proposals, credential expiry, stuck POs, sequence due | schedule + thresholds (doc 24) |

3. **Cascades are transitions' side effects**, never manual second
   steps: invoice `paid` → team + investor payouts `blocked→payable` ·
   deploy `healthy` + recorded acceptance → invoice `draft→sent` ·
   funding `funded` → POs become fundable · outbox send → follow-up
   scheduled · inbound reply → pending outbox cancelled.
4. **Guards outrank gestures** — a drag to `payable` on the payouts
   board is refused; only cascade #3 gets rows there.
5. **Prices never move with status** — snapshots (proposals, invoices,
   investments, fees) are frozen at creation; a status flip cannot
   edit an amount. Change of scope = new proposal (doc 04).
6. **Cancelled ≠ deleted** — every terminal state keeps its row and its
   history; nothing is hard-deleted anywhere.

---

## State machine catalog

### Sales

| Entity | Stages | Key transitions (trigger → next) | Guard / side effect |
|---|---|---|---|
| **Lead** | discovered → contacted → demo_built → demo_shared → proposal_sent → negotiating → **won \| lost** (+archived) | first email sent → contacted · demo live → demo_built · L5 sent → demo_shared · L7 sent → proposal_sent · reply → negotiating · **acceptance recorded → won** (runs doc 5 conversion) · L4 chain ends → lost | won triggers conversion workflow; lost requires `lost_reason`; any reply cancels pending nudges |
| **Campaign** | draft → running → paused → done | start · pause · end date cron | targets stop scheduling when paused |
| **Campaign target** | scheduled → sending → sent → delivered \| failed \| skipped | send action · reply detected → skipped | stop_on_reply per sequence_steps |
| **Demo** | building → live → archived | repo ready → live · expires cron → archived | live = short_link active |
| **Proposal** | draft → sent → viewed → **accepted \| rejected \| expired** | Send modal → sent · link ping → viewed · **pasted "accepted" → accepted** · owner records rejection · cron at valid_until → expired | accepted stores `acceptance_channel=email` + note + accepted_price; expired frees the lead for re-quote |

### Delivery

| Entity | Stages | Transitions | Guard / side effect |
|---|---|---|---|
| **Project** | planned → in_progress → delivered \| **on_hold** \| **defaulted** → written_off | intake answered → in_progress · acceptance + payment → delivered · 2nd silence → on_hold · doc 20 freeze → defaulted → (distributions complete) written_off | defaulted runs the default workflow (below) |
| **Module order** | requested → quoted → accepted → building → in_review → deployed → **invoiced** \| cancelled | ticket → requested · mini-proposal sent → quoted · pasted accept → accepted · T2 sent + PR opened → building · PR merged → in_review · deploy tag → deployed · invoice sent → invoiced | flat team_fee fixed at accepted; deployed schedules deploy via adapter |
| **Purchase order** | draft → ordered → received → installed → invoiced | items priced → draft · V3 sent + funding bound → ordered · receipt uploaded → received · install confirmed → installed | ordered requires `funding_id` (or waiver); received **requires** `receipt_url` (doc 19) |
| **Client device** | ordered → shipped → installed \| faulty → rma | PO received → shipped · install → installed · fault reported → faulty · V8 sent → rma | warranty shown from day one |
| **Update PR** | open → merged \| closed | GitHub webhook | merge bumps live_tag after deploy |
| **Deploy target** | never_deployed → healthy \| degraded \| pending_agent | first deploy · healthcheck cron · agent heartbeat loss | healthy is the invoice gate's precondition |

### Money

| Entity | Stages | Transitions | Guard / side effect |
|---|---|---|---|
| **Invoice** | draft → sent → viewed → **paid** \| overdue \| void \| **uncollectible** | created from snapshot → draft · P1 sent → sent · link ping → viewed · **webhook or Mark paid → paid** · cron past due → overdue · owner voids (mistake) · doc 20 → uncollectible | **paid fires the payout cascade** — the app's central transition |
| **Team payout** | accrued → **blocked** → payable → paid \| cancelled | work delivered → accrued+blocked · **cascade #3 → payable** · owner marks paid (bank ref) → paid · project defaulted → cancelled | blocked rows show `unblock_payment_id` reason; drag refused |
| **Funding round** | seeking → committed → funded → returned → closed | I2 sent → seeking · commitments ≥ target → committed · bank confirmed → funded · all payouts paid → returned → closed | salvage rounds carry `salvage_of_project_id` |
| **Investor payout** | accrued → blocked → payable → paid \| cancelled | terms recorded → accrued+blocked · cascade #3 → payable · marked paid → paid · default → upside cancelled | split rows encode seniority (docs 19–21) |
| **Subscription** | trial → active → paused \| cancelled | signup · first invoice → active · pause request · cancel / P6 reply | renewal cron schedules P6 |

### People & infra

| Entity | Stages | Transitions | Guard |
|---|---|---|---|
| **Connector** | requested → provisioned → connected \| broken | owner provisions under client OAuth → provisioned · healthcheck ok → connected · token fails → broken | broken auto-creates a ticket (doc 15) |
| **Credential** | active → **revoked** | vault write → active · rotation replaces (new row, old revoked) · offboarding → revoked | reads are audited; revoke is irreversible by design |
| **External client cost** | active → downgraded \| cancelled | tracked row · client reports change (paste-reply) | advisory only — never billed |
| **Outbox item** | scheduled → ready → sent \| skipped (cancelled) | sequence schedules · due cron → ready · Send modal → mark sent · reply/status change → cancelled | send auto-schedules the chain's next step |

---

## Workflow catalog (end-to-end, cross-entity)

**W1 · Cold lead → cash** (the spine):
campaign target scheduled → L1–L4 sequence · reply → lead flips +
queue cancels · demo built → L5 · proposal (Quote engine, snapshot) →
L7 · pasted "accepted" → proposal accepted → **conversion** (client +
sale rows, doc 5) → welcome + intake (C1–C3) → build (C4) → review
(C5–C6) → deploy → live (C8) → acceptance (C9–C10) → invoice (P1) →
payment → **payout cascade** → thanks (P5) → handover (C11) →
maintenance (C12).

**W2 · Upsell an existing client**: ticket → change-scope quote (C7 /
doc 04) or module order (W3) → proposal → accept → deliver → invoice.

**W3 · Module add-on build** (doc 14): request → mini-proposal →
accepted module_order (flat fee) → build spec rendered → T2 brief →
PR → in_review → merge → deploy tag → deployed → invoice → payment →
fee payout.

**W4 · Custom project with procurement + investor** (doc 19): project
+ PO draft (items priced) → funding round (I2–I5) → PO funded +
assigned → V3 instruction → receipt → install → deploy → acceptance →
invoice → payment → **tier cascade** (recovery → team → principal →
upside → margin).

**W5 · SaaS subscription**: sale (price_model=saas) → trial → first
Lane C invoice → active → renewal cron (P6) → paid / paused / churn.

**W6 · Investor round** (docs 13/19): round seeking → offers sent →
commitments → funded → trigger-bound payouts wait → cascade on client
payment → returned → closed.

**W7 · Default & loss** (doc 20): default radar fires → owner freezes
(project defaulted, invoice uncollectible, upside cancelled, POs
halted) → liquidate (asset_dispositions) → recovery distributions
pro-rata to capital → realized loss computed → I9/I10 sent → written_off.

**W8 · Salvage play** (doc 21): post-mortem → contacts → campaign →
code → template birth → servers repurposed → salvage round → W4 again
with enhanced tiers.

**W9 · Vendor loop** (doc 12): V1/V2 sourcing → PO ordered (V3) →
chase (V4) → receipt (V5) → remittance (V6) · disputes (V7) / RMA (V8).

**W10 · Template maintenance** (doc 11): GitHub release → all repos
show behind-by → update PRs open (bulk) → merge → deploy → tag.

**W11 · Credential lifecycle** (doc 15): provision under client OAuth
→ vault write → healthcheck cron → rotate (old revoked) → offboarding
revoke-all checklist (owner executes from a generated list).

**W12 · Daily loop** (doc 18/22): Today → paste replies (flips) →
send-today (outbox) → money actions (cascades) → blockers → zero.

**W13 · Weekly review** (doc 24): 15-min guided six-pillar pass →
decisions pushed into Today → next week executes them.

**W14 · Offboarding** (doc 15): final invoice → revoke-all → repos
per `repo_policy` → data export → clients offboarded →
external_client_costs advisories closed.

**W15 · Deployment & rollback** (doc 16): merge → adapter deploy →
healthcheck → healthy (or pending_agent → wait) → rollback button on
any provider.

## Terminal states & what each means

| State | Meaning | Reversible? |
|---|---|---|
| lost / rejected / expired | deal died with dignity; rows kept for analytics | re-quote allowed (new proposal) |
| cancelled | work or payout called off; reason in note | new row, never a resurrection |
| defaulted → written_off | client vanished; recovery finished; loss final | no — salvage happens as a **new** project (W8) |
| void | invoice mistake, pre-payment | new invoice |
| uncollectible | debt given up; counted in loss metrics | no |
| revoked | credential dead by design | issue a new one |
| archived | dormant but restorable (demos, leads) | yes |

## Schema delta

**None.** v10 stands — this document is process over existing columns.
The only new artifact is behavioral: the `flip()` write path and the
cascade/guard registry it consults.
