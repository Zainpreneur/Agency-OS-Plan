# 19 — Worked Example: the POS + Hardware Deal (paper-trail walkthrough)

The full scenario, traced row-by-row through this plan's schema — the
acceptance test for docs 12, 13, 14, 18 combined.

**Deal**: WhatsApp client wants a POS system with hardware (drawer,
barcode reader, terminal). Agency fronts nothing: one investor funds the
2,000 procurement, a team member executes the purchases for a flat 2,000
fee, client pays 10,000. Outcome: investor repaid 2,000 + 1,000 profit,
team paid 2,000, agency keeps 5,000. Nobody but the owner sees any of it.

---

## The paper trail, step by step

| # | What happened | Rows created / flipped |
|---|---|---|
| S1 | WhatsApp chat: "we need a POS with drawer, barcode reader…" | `comms_log` (in, whatsapp, snippet) + `leads`/`clients` row |
| S2 | Owner logs the request | `tickets` row → `projects` (kind=custom_software, "Alnoor POS") |
| S3 | Hardware spec drafted from conversation | `purchase_orders` **draft** + `purchase_items`: barcode reader @ vendor X · cash drawer @ vendor Y · POS terminal + display @ vendor Z → `total = 2000` |
| S4 | Investor close (procurement only) | `project_funding` (target 2000 → **committed**) + `investments` (amount 2000, `return_rule=fixed`, `promised_return=3000`, `funds_received_at` set) → funding **funded** |
| S5 | PO bound to restricted pot + executor | PO `funding_id` = that funding (procurement-only money, doc 13); PO `assigned_team_member_id` = the team member |
| S6 | Proposal to client (setup + hardware, 10,000) | `proposals` row, **snapshot 10,000** (Quote-engine lines: hardware pass-through + setup fee) → `proposal_send` template → `wa.me` link → `comms_log` (out). Client replies OK → `acceptance_channel=whatsapp`, `acceptance_note` = pasted reply |
| S7 | Procurement instruction to team member | `pos_procurement_instruction` template rendered (items, vendors, unit prices, budget 2,000, "collect receipts") → email/WhatsApp → `comms_log` |
| S8 | Team member buys | PO `ordered` → `received` (`received_at`, `receipt_url` = photo of receipts) + `expenses` row (money_out · hardware · 2,000 · drawn from the restricted pot) |
| S9 | Install + register client hardware | `client_devices` rows (terminal, drawer, scanner — serials, `warranty_until`, status installed); POS software built as `module_orders` (flat team fee = 0 here, fee already on the project) |
| S10 | Handover | deploy/`live_notice` message → recorded acceptance → `invoices` **10,000 at snapshot price** + payment link sent (Lane A) |
| S11 | Client pays | `payments` row (webhook) or owner clicks **Mark paid** (`payment_confirmation=manual`) → guards fire (see below) |
| S12 | Obligations released & settled | below |
| S13 | Month-end | `investor_monthly` summary + payout digest generated for sending; project margin report shows the 5,000 |

**Card rule check**: hardware is bought with the *investor advance*
(agency account, restricted) — the client's card rule (doc 15) governs
*recurring third-party SaaS* (Lane B), not PO-funded hardware (Lane A
pass-through). No conflict.

## The money: who gets paid from the 10,000

Guards fire the moment `payments` records the 10,000:

| Tier | Who | Amount | Ledger row |
|---|---|---|---|
| 1 | Investor — **principal** | 2,000 | `investor_payouts` #1 (trigger = the 10k payment) |
| 2 | Team member — flat fee | 2,000 | `payouts` (blocked → payable) |
| 3 | Investor — **upside** | 1,000 | `investor_payouts` #2 |
| 4 | Agency — margin | 5,000 | remainder (project report) |

**Key move**: the investor's 3,000 is booked as **two** `investor_payouts`
rows (principal first, upside *after* the team fee) instead of one fixed
3,000 row. The schema allows any number of rows per investment — so the
tiers encode seniority for free. If the client had paid only 4,000
(late/partial), principal + team fee still clear and the upside waits;
nobody's money silently absorbs a shortfall.

## The math (always derivable, never hand-remembered)

```
revenue (snapshot)          10,000
− team fee                   2,000
− investor return            3,000   (2,000 principal + 1,000 profit)
− procurement                2,000   (borne by investor advance, repaid in tier 1)
──────────────────────────────────
agency profit                5,000
agency cash outlay               0   (investor fronted procurement)
```

Every line above is a row: invoice snapshot, payouts, investor_payouts,
purchase_orders/expenses. The "profit" is computed from ledgers, not
remembered from the chat.

## Failure modes, rehearsed

- **Client pays late/partial** → tiers 1–2 clear first; upside (tier 3)
  stays `blocked`; dashboard nag list shows the unpaid invoice
- **Vendor price rises (2,000 → 2,300)** → new PO line at the *actual*
  price; the 300 gap is either agency margin shrink or a change-order
  proposal (doc 04) — snapshot keeps the original promise honest
- **Hardware faulty** → `client_devices.status=faulty` + RMA; PO/receipt
  already proves provenance and warranty date
- **Team member never returns receipts** → PO stuck at `ordered` is
  visible in the daily queue (doc 18)
- **Investor asks "where's my money?"** → `investor_monthly` summary
  generated from rows, sent by WhatsApp; nothing to show them in-app
  (solo mode)
