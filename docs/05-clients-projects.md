# 05 — Clients, Projects, Tickets & Upsell Matrix

## Client 360

Every client record shows: owned products, active subscriptions, open
tickets, lifetime revenue, true margin, deployment branches (if
multi-branch), assigned team, and the **product-need matrix** on top.

## Product-Need Matrix (the self-selling screen)

```
                          Website  Software  Maintenance  POS
Al-Noor Carwash             ✗         ✓           ✓        ✗   → upsell WEBSITE
Furniture Store             ✓         ✗           ✗        ✗   → upsell SOFTWARE
Al-Noor Laundry             ✓         ✓           ✓        ✗   → upsell POS
```

A nightly rules job scans every client against `upsell_rules`:

```sql
upsell_rules(has_category='business_software', missing_category='website',
             suggested_template_id=…, active=TRUE)
```

and writes `opportunities(kind='gap_upsell', detected_by='rule')`. Nobody has
to remember to think about it.

### Signals, not just rules

- A ticket tagged `feature_request` ("can it do inventory reports?")
  auto-creates a **hot** opportunity with `reason_detail` pointing at the
  ticket — the best-qualified lead you'll ever have
- Renewal window approaching + recent feature questions → priority hot

### Opportunity lifecycle

`identified → demo_built → proposed → won / dismissed`

- Dismissals **must record why** (budget / happy with Wix / not now)
- "not now" auto-re-opens in 90 days; "never" stays closed — otherwise the
  board becomes noise
- Won upsells = **expansion revenue**, tracked separately from new clients

## Projects

`projects(client_id, sale_id, github_repo, scope, status, budget)` — the
delivery side of a sale. The repo is installed with the GitHub App:

- pushes → activity on the project timeline
- PRs merged → progress on linked tickets
- `time_entries.project_id` → burn vs budget

## Tickets (support + customization)

- Created manually or from GitHub issues (`issue.opened` webhook on delivery
  repos; labels pick the type: `bug` / `customization` / `retainer`)
- Types: `customization | support | bug | feature_request`
- **The maintenance subscription grants the SLA queue** — that's what makes
  the 200–300/mo recurring revenue instead of favors
- Tickets link to `opportunity_id` when they become sales leads
- Can reference a `deployment_id` for multi-branch clients ("which of the 15
  branches needs help")

## The views

```
💡 Opportunities board (Monday-morning sales list)
🔥 HOT: Client B — needs software (asked inventory in ticket 47) [Demo][Propose]
💛 WARM: Client A — needs website (gap rule)                     [Demo][Propose]
```
