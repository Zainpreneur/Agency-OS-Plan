# 20 — Loss & Default Waterfall (the mirror image)

Every project can end in profit **or loss**. Doc 19 showed the happy
path; this is the unhappy one, traced with the same rigor.

**The scenario**: custom software quoted 30k, cost 20k (10k servers from
vendors + 10k team fee). Two investors each fund 10k, promised 3k profit
each on top. Client vanishes before paying anything.

---

## What the guards already did (before you touched anything)

This is the quiet win of the blocked→payable design:

| Obligation | Size | What happened when the client vanished |
|---|---|---|
| Team fee | 10,000 | `payouts.status = blocked` — the `unblock_payment_id` (client payment) **never exists**, so it never became payable. No cash left |
| Investor returns | 26,000 | `investor_payouts.trigger_payment_id` never set → rows stay blocked. The 3k "promise" fires **only against real revenue** |

**Actual cash at risk: 20k in → 10k spent (servers) → 10k still sitting
in the pot, untouched.** The loss is not 26k or 30k. It's whatever
liquidation fails to recover from 10k of unspent money + 10k of servers
+ the code itself. The platform's job is to make that number exact and
every dinar accounted for.

---

## The default protocol (freeze → liquidate → distribute → record)

### 1. Freeze (one action, everything cascades)

- `projects.status → defaulted`
- `invoices.status → uncollectible` (never `paid`; the 30k is not revenue)
- `module_orders` → cancelled; `investor_payouts` upside rows → `cancelled`
- Daily queue now shows the defaulted-project worklist until closed

### 2. Liquidate (convert everything back to cash)

| What | Options | Recorded in |
|---|---|---|
| Unspent investor pot (10k) | it *is* investor cash — first line of recovery | `recovery_distributions` |
| Servers (10k bought) | return to vendor (~90% back) · resell · **repurpose to another client or own SaaS** (book value) | `asset_dispositions` (proceeds, fee, buyer) |
| The built code | becomes internal IP / future template — value realized on its *next* sale, not booked here | `module_orders` notes + post-mortem |

### 3. Recovery waterfall (exact mirror of doc 19's profit tiers)

| Tier | Who | Rule |
|---|---|---|
| 1 | Investors — **capital** | unspent pot + liquidation proceeds, **pro-rata to amounts in** (10k/20k each = 50%) |
| 2 | Team — optional goodwill | ONLY if the work was actually delivered and the owner chooses to honor it; **from agency's own pocket or explicitly after investors** — never out of investor capital silently |
| 3 | Investors — upside | **permanently cancelled** — no revenue, no return |
| 4 | Agency | absorbs every remaining shortfall first |

Worked math (servers returned at 90%):

```
recoverable:  unspent pot 10,000 + server return 9,000 = 19,000
distributed:   9,500 per investor (pro-rata 50%)
realized loss:   500 per investor  ·  total project loss 1,000
agency cash out: 0 (loss sits with capital, per the agreement)
```

If servers only resell at 70%: recovery 17k → 8,500 each → loss 1,500
each. The number is always **derived from rows**, never negotiated from
memory.

### 4. Record (the ledger of the loss)

- `recovery_distributions` rows: source (`unspent_pot|liquidation|agency_goodwill`), amount, per-investor share
- **Realized loss = `investments.amount` − Σ distributions** — computed, shown in each investor's generated monthly summary
- Post-mortem note on the project: what failed, which gate would have prevented it

---

## The refund challenge ("we want our money back")

Three facts the platform puts behind every conversation:

1. **The contract snapshot**: `project_funding.terms_summary` +
   `agreement_url` captured *at funding time*, before money moved. The
   agreement says: capital at risk, return fires on client payment.
   There was never a refund obligation — only a distribution rule.
2. **The trigger design**: their 3k each was never a debt; it was
   contingent on revenue that never happened. If you had *guaranteed*
   it regardless of the client paying, **that would be a loan, not an
   investment** — the platform refuses to record guaranteed returns as
   `investments` (see prevention gate 5).
3. **The recovery statement**: what was spent where, what was salvaged,
   their exact share, their exact loss — a generated message with rows
   behind every line (solo mode: `project_defaulted_notice` template).
   Nothing is argued from memory.

The honest emotional truth: investors may still be upset — but they see
the same numbers you do, computed the same way, and the pot that still
had 10k in it was never touched for anything else. Segregated
project pots (`funding_id` on every spend, doc 19) mean one dead
project can never silently eat another project's — or an investor's —
money.

---

## Prevention gates (the real deliverable of this doc)

Every default teaches the platform one rule it now enforces:

1. **Deposit-before-procure** — `purchase_orders` funded by investor
   advance require a recorded client deposit ≥ a threshold, or an
   explicit `deposit_gate_waiver` note. Had this client paid a 10k
   deposit first, the entire loss would have been covered.
2. **Milestone buying** — servers procured per milestone tranche, not
   upfront; the PO list mirrors the client's payment tranches.
3. **Concentration cap** — flag funding targets where one project eats
   > X% of an investor's deployable capital (this deal: 100%, twice).
4. **Margin sanity** — flag cost/revenue ratio < threshold (this deal:
   30k vs 20k = 33% margin on custom software with zero deposit — thin).
5. **Guaranteed-return-is-debt** — any "fixed return regardless of
   client payment" is recorded as a **loan** (agency obligation), never
   as investment. The distinction is enforced at data entry, not in the
   argument afterward.
6. **Client-vanish early warning** — a project with procurement started
   and zero client payments after N days appears on the nag list *while
   servers are still returnable*.

---

## Schema deltas (v5)

- `projects.status` gains `defaulted` (then `written_off` when
  distributions complete)
- `invoices.status` gains `uncollectible`
- `investor_payouts.status` gains `cancelled`
- `purchase_orders.deposit_gate_waiver` — explicit, audited override
- `asset_dispositions` (project_id, po_id/kind, disposition
  returned|resold|repurposed, proceeds, fee, at)
- `recovery_distributions` (investment_id, source, amount, at)
- Message template `project_defaulted_notice` — facts only: spent what,
  salvaged what, your share, your realized loss
