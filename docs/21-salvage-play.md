# 21 — The Salvage Play (dead deal → next deal → everyone whole)

Continuation of doc 20. The defaulted client was a **hotel** needing
on-premise custom software + hardware. 50 hotel contacts remain, the
built code exists, the servers exist. You pitch 30 of them, **one
accepts at 60,000** — and the survivors (the two burned investors, the
team that worked unpaid) get *extra* value on this deal. Seamless = the
platform models it with **two new columns and one source code**, not a
new subsystem.

---

## What survived the default (the salvage inventory)

| Surviving asset | Where it lives in the platform | How it converts |
|---|---|---|
| 50 hotel contacts | post-mortem note + `leads` (the dead client defined the ICP) | campaign "hotel vertical" → 30 pitched → 1 sale (3.3% on a warm list with a real product) |
| The built software | `module_orders` code → becomes a **`templates` row** (doc 2/14: internal template born from a dead deal) | new proposal generated via the Quote engine (doc 17) — quoting takes minutes |
| The servers (10k bought) | `asset_dispositions`: `disposition = repurposed` at net book **9,000**, counterparty = the new project | settlement owed to the dead project's recovery pot **when the new client pays** |

## Why repurpose beats return

Returned at 90%: 9k cash *now*, minus restocking risk. Repurposed at 9k
book: same 9k, but **the new project avoids buying servers at 10k** —
so the 60k deal's cost basis drops ~1k and the discount risk
disappears. The recovery simply waits for the deal you control.

Dead-deal settlement (doc 20 chain, closed by the new sale):

```
unspent pot 10k      -> 5k per investor   (distributed at default)
server transfer 9k   -> 4.5k per investor (on the 60k payment)
realized loss:         500 per investor   — now history, fully documented
```

## The salvage round (where "extra value" lives, honestly)

New project opens a funding round tagged **`salvage_round`**
(`project_funding.source_kind`, `salvage_of_project_id` → the dead
project), **offered first to A and B** with enhanced terms:

- each invests **10,000** again — used for hardware top-up + working capital
- `promised_return = 15,000` each (not 13k) — the extra value, justified
  because the IP and servers they already paid for **de-risk this deal**
- still **trigger-bound** to the 60k payment — enhanced ≠ guaranteed;
  the doc 20 guards apply unchanged
- the concentration flag fires (it should!) → explicit recorded waiver,
  same pattern as `deposit_gate_waiver`

## The team (flat-fee rule respected)

The dead deal's blocked 10k fee → cancelled there (doc 20 policy), **but
the work isn't forgotten**: the new deal's fee is set to include it —
paid only where cash exists:

| Row | Kind | Amount | Guard |
|---|---|---|---|
| Adaptation + installation | `delivery` | 10,000 | blocked → payable on the 60k |
| Salvage bonus (the IP that made this sale possible) | `bonus` | 2,000 | blocked → payable on the 60k |

Flat amounts per deliverable — no hourly, no monthly. The unpaid old
work is honored by riding a deal that *has* cash, never by breaking the
guard.

## The 60,000 waterfall (all rows, all trigger-bound)

| Tier | Who | Amount | Row |
|---|---|---|---|
| 1 | Dead project's recovery pot (A/B pro-rata 4.5k each) | 9,000 | `recovery_distributions` (source=`repurposed_sale`) |
| 2 | Team — delivery 10k + bonus 2k | 12,000 | `payouts` ×2 |
| 3 | Investors A & B — principal | 20,000 | `investor_payouts` (2 rows) |
| 4 | Investors A & B — enhanced upside 5k each | 10,000 | `investor_payouts` (2 rows) |
| 5 | Agency — margin | **9,000** | remainder |

```
60,000 − 9,000 − 12,000 − 20,000 − 10,000 = 9,000 agency margin
```

## Net outcome per party (the honest bottom line)

| Party | Across both deals | Where it's proven |
|---|---|---|
| Investor A / B | −10k in, 9.5k back (old) + 10k in, 15k back (new) = **+4,500 each** | every dinar a row; the 500 old loss is visible, not buried |
| Team member | old 10k cancelled, new 12k paid = **12,000** for the whole arc | two flat rows, one bonus, both guarded |
| Agency | **9,000 margin + owns the hotel template + 49 warmed leads** | the template is the real win: next hotel sells at near-zero build cost |

## Platform integration points (the "seamless" part)

1. Campaign row (hotel vertical) with attribution back to the defaulted
   project's post-mortem — the ICP insight is a first-class link
2. Template birth from `module_orders` code → next quote via Quote engine
3. `asset_dispositions` + `recovery_distributions(source=repurposed_sale)`
4. `project_funding.source_kind = salvage_round` + `salvage_of_project_id`
5. Team `bonus` row alongside the `delivery` row
6. Solo-mode messages: `hotel_pitch` (×30), `salvage_round_offer` (to
   A/B), settlement statements on payment
7. On-premise delivery uses doc 16's office-VPS/pull-agent adapter +
   `client_devices` for hotel hardware

**Schema v6: two columns + one source code.** That's the whole seam.
