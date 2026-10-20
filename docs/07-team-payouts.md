# 07 — Team Payouts (revenue-share payroll)

Three team members. **Nobody gets a salary — a payout exists only because a
revenue event happened, and only once the client's money actually arrived.**

## The model

```
Client buys website 3,000 ── invoice PAID ──► Builder A:  +500 (one-time)
Maintenance 300/mo ──────── sub active ─────► Maintainer B: +100/mo (while valid)
                                               You keep: 2,500 + 200/mo
```

## Tables

```sql
team_members (id, name, pay_model [revenue_share|fixed|hourly], status, joined_at)

comp_plans   (id, team_member_id, applies_to 'website',
              kind [delivery_fee|milestone|monthly_support|bonus],
              amount, trigger [sale_won|invoice_paid|delivered|subscription_active],
              active)

payouts      (id, team_member_id, client_id, sale_id, subscription_id,
              comp_plan_id, kind, amount,
              status [accrued|blocked|payable|paid|cancelled],
              accrued_at, unblock_payment_id, payable_at, paid_at, paid_via, notes)
```

**The two-status trick is the whole design:**
`accrued` (owed in principle) → `blocked` (waiting on client payment) →
`payable` (cash is in) → `paid` (Friday run).

## Lifecycle example

1. **Setup:** comp_plans — A: `delivery_fee 500 trigger invoice_paid`;
   B: `monthly_support 100 trigger subscription_active`
2. **Sale won (3,000 + 300/mo):** payout row for A accrues, immediately
   `blocked` (unblock_payment_id = the 3,000 invoice)
3. **Client pays** → webhook flips A's payout to `payable` → next Friday run
   pays 500
4. **Every month:** maintenance invoice paid **and** subscription active →
   accrue B's 100 as `payable`
5. **Subscription cancelled** → future accruals stop automatically — "till
   it's valid" is enforced by the system, not memory
6. **Late client** → their invoice unpaid → B's 100 stays `blocked` — your
   outflow never runs ahead of inflow

## Team page

```
A. Builder · laptop ZP-LAP-01 · pay: revenue share
   Active delivery payouts: 1 (furniture, 500, awaiting client payment)
   Paid YTD: 4,200 · Next run Fri: 500

PAYOUT RUN — Friday
  Payable: A 500 + B 200 = 700 SAR   [ Approve & mark paid ]
  Blocked: A 500 (invoice pending) · B 100 (invoice unpaid 6d → remind client)
```

## Guardrails

- Every payout traces to a `comp_plan` + trigger event (fully auditable)
- `kind='adjustment'` payouts allowed but must carry a written reason
- **Alert if a client's cumulative payouts > lifetime revenue** — an
  underpriced maintenance sub shows up there before your gut notices
- Offboarding checklist: return laptop (asset_assignments) + cancel license
  seats (asset_licenses) + pause future accruals + offer buyout of accrued
