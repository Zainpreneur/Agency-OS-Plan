# 12 — Custom Projects & Procurement (the 50k build)

A new project `kind`: **`full_build`** (vs template customization), with a
**budget breakdown enforced at creation**:

```
Project: Farm-IoT Platform (GreenFields)   kind: full_build
Contract: 50,000 SAR (milestone invoices)
Budget:   Hardware 15,000 · Team 10,000 · Other 5,000  (= 30,000 target cost)
Funding:  30,000 sought → committed (3 investors)      → see doc 13
```

## Procurement (hardware is a process, not an expense row)

```sql
purchase_orders (id, project_id, vendor, kind [hardware|services],
                 total, status [draft|ordered|received|installed|invoiced],
                 ordered_at, received_at)
purchase_items  (po_id, sku, description, qty, unit_cost)  -- sensors, gateways…

client_devices  (id, project_id, client_id,
                 serial_no, kind [gateway|sensor|camera],
                 firmware_version, site_location,          -- "Pump station 2"
                 warranty_until,
                 status [ordered|shipped|installed|faulty|rma])
```

**Why `client_devices` ≠ your `assets` register:** their gateways sit on
*their* farm and need serial/firmware/RMA tracking; your 5 laptops are your
own cost center. Tickets can reference `device_id` ("sensor array B offline
at pump station 2"); RMA is a workflow, not a forgotten phone call.

## Live margin on the project

| When | What writes |
|---|---|
| POs received (15k hardware) | `expenses(kind=hardware, project_id)` per invoice |
| Team works | `time_entries` → payouts accrue via comp_plans (the 10k) |
| Cloud/travel/licensing | `expenses(kind=other, project_id)` (the 5k) |

```
Contract 50,000 · Spent 21,400 · Committed (open POs) 8,600 · Payouts accrued 6,200
Forecast at completion: 50,000 − 30,000 = 20,000 gross
after investor returns (15,000) → 5,000 to agency          ← the number that matters
```
