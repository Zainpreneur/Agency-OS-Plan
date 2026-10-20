# 14 — Module Add-ons (AI-assisted builds, flat team fees)

An existing client asks for a new capability on their deployed custom
software: *"can the POS do staff attendance + salaries?"* — the HR module
scenario. Not hourly, not monthly: **flat fee per deliverable**, built by a
team member with OpenCode / Claude Code, shipped through the repo pipeline.

## The path (one ticket to one payout)

```
WhatsApp: "can the POS do staff attendance + salaries?"
 ① ticket (type: feature_request → client + project + repo linked)
 ② one-click [ Quote module ] → mini-proposal: HR Module 3,000 (snapshot)
 ③ client accepts on tracked link
 ④ module_order created: team_fee 500 FLAT → assigned to team member C
 ⑤ platform renders BUILD SPEC → C opens repo in OpenCode/Claude Code, pastes
 ⑥ branch module/hr → build → PR → review → merge = deploy → tag v1.x
 ⑦ invoice 3,000 sent → payment webhook
 ⑧ payout: C +500 accrued → BLOCKED → unblocked by payment → Friday run
```

## Schema

```sql
module_orders (
  id, client_id, project_id, ticket_id, proposal_id,
  name 'HR Module', scope,
  price 3000,                       -- what the client pays
  team_member_id, team_fee 500,     -- FLAT — overrides comp_plans default
  ai_tool,                          -- opencode | claude_code
  status [requested|quoted|accepted|building|in_review|deployed|invoiced|cancelled],
  branch 'module/hr', pr_number,
  build_spec TEXT,                  -- the generated prompt (see below)
  started_at, deployed_at, invoice_id)
-- payouts.module_order_id → the 500 traces to this row
```

## The three design pillars

**① Build spec is a first-class artifact.** On `accepted`, the platform
renders a prompt package: module scope + the client's stack, brand tokens,
existing modules + repo conventions. Whoever opens the AI tool pastes one
thing and builds to spec. **The AI tool varies; the spec doesn't.**

**② Fee lives on the order, not a rate sheet.** `comp_plans`
(kind=delivery_fee, trigger=invoice_paid, amount=500) is the *default*;
`module_order.team_fee` overrides per deal. The payout accrues the moment
the 3k invoice is paid, blocked until then — same cash-flow guard as every
other payout. C's portal shows `blocked (invoice pending)` → `payable Friday`.

**③ Deploy = merge = tag.** GitHub App watches the `module/hr` PR → merged →
deploy hook → live tag → client pinged "HR module live at 14:32". Cycle
time (requested → deployed) falls out as a metric. The module is now **their
code in their repo** — future fixes are change requests; template-level HR
improvements can PR into their repo later, same as website clients.

## Where it shows up

- **Client 360:** "Owns: POS ✓ · HR module ✓ · Website ✗" — the upsell
  matrix sees the new module automatically
- **Delivery page:** the module card sits inside their project with branch,
  PR, invoice, payout attached
- **Retainer math:** module support minutes count against the same
  maintenance bucket (or spawn its own sub, if priced that way)

## Platform philosophy note

> "Build for yourself before you build for others."

Every one of these flows was lived first: this HR-module path is the same
one used to build Agency OS's own modules — ticket → spec → AI build in
OpenCode → PR → deploy → payout. The dogfood loop is the roadmap.
