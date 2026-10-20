# 09 — Multi-Branch Product Schema (carwash, 15 branches)

The *software you sell* (e.g. the carwash product) supports multi-branch with
**one app, one database — branches are rows, not deployments**.

## Core principles

| Rule | Why |
|---|---|
| `businesses` is the tenant root | Same codebase hosts thousands of clients |
| `branch_id` on every transactional row | "Which branch washed this car?" is always answerable |
| Denormalize `business_id` everywhere | Fast isolation; enables Postgres Row-Level Security with zero query rewrites |
| Shared vs scoped split | The car follows the customer across all 15 branches; a sale is one branch's |
| Config hierarchy: business default → branch override | One price list; the airport branch charges +20% |
| Branches are data | Branch #16 = an INSERT, not a server |

## Schema

```
businesses    (id, name, currency, timezone, tax_rate, settings JSON)
branches      (id, business_id, code, name, address, geo, phone,
               manager_user_id, status[planned|setup|live|suspended], settings)
devices       (id, business_id, branch_id, label, kind[pos|kiosk|tablet])

users         (id, email, name, password_hash)
memberships   (id, user_id, business_id, branch_id NULL=all, role[owner|manager|cashier|washer])

services      (id, business_id, name, base_price, duration_min, active)
branch_services (branch_id, service_id, price, …)          -- overrides

customers     (id, business_id, full_name, phone, …)        -- SHARED
vehicles      (id, business_id, customer_id, plate_no, …)   -- SHARED

bookings      (…, branch_id, customer_id, vehicle_id, slot_start, source[walk_in|app|phone])
work_orders   (…, branch_id, booking_id, status[queued|washing|qc|ready|delivered], totals)
work_order_items (work_order_id, service_id, qty, unit_price)  -- PRICE SNAPSHOT

staff / staff_branches                                    -- floaters cover several
shifts        (…, branch_id, opened_by, opening_float, counted_cash)
payments      (…, branch_id, work_order_id, shift_id, method[cash|card|transfer|online])
daily_branch_sales (branch_id, business_date, gross, net, cars_count)  -- rollup

products / inventory_moves (…, branch_id, reason[purchase|usage|transfer|adjust])
```

## Query rules

```ts
// session = { businessId, branchIds: number[] | 'ALL' }
// owner: branch_id NULL sees all 15; cashier sees only own branch
db.select().from(workOrders).where(and(
  eq(workOrders.businessId, session.businessId),
  session.branchIds === 'ALL' ? undefined
    : inArray(workOrders.branchId, session.branchIds),
));
// HQ dashboard: sum/count GROUP BY branch_id → O(15) via daily_branch_sales
```

## The four pitfalls (they break multi-branch if skipped)

1. **Branch names instead of IDs** — renaming a branch makes old invoices
   lie. IDs everywhere; snapshot names only on printed documents.
2. **Customers scoped per branch** — 15 duplicate "Mohammed Al-Farsi"
   records. Customers/vehicles are business-scoped, always.
3. **Prices by reference** — always snapshot `unit_price` on line items; a
   later price change must not rewrite sales history.
4. **Scoping only in the frontend** — scope in SQL or a tampered API call
   reads another branch's payroll.

## Deployment shape

- One app instance + one DB (SQLite → Postgres as the client grows)
- Each branch's POS tablet = a `devices` row pinned to `branch_id`; kiosk
  login auto-scopes every write
- Offline tolerance: the device queues writes client-side with `branch_id`
  stamped, flushes on reconnect — no schema change needed

## Tracking deployments in the Agency OS

```sql
sales   (+ branch_count, tier [single|multi_branch|enterprise],
          price_model [one_time|per_branch|saas])
deployments (id, sale_id, branch_label, city,
             status[sold|config|data_import|training|live|suspended],
             planned_go_live, actual_go_live, contact_*)
```

- Project page → rollout board: 15 branch cards, drag sold→config→live
- Milestone invoices reference `deployment_id` line items
- Tickets tag the exact branch needing help → linked GitHub issue
- Health signal: a branch stuck in `training` for 30 days or a live branch
  opening zero tickets
