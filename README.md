# Agency OS — The Full Plan

An all-in-one operating system for a software agency that **sells and customizes
software templates**: lead generation, demo generation, proposals, delivery,
support, invoicing, team payouts, asset tracking, and true-cost accounting.

Built to run on the stack recommended in
[`Zainpreneur/tech-stacks`](https://github.com/Zainpreneur/tech-stacks).

---

## The philosophy

1. **GitHub is the product database** — repos, releases, and issues are synced,
   never duplicated by hand.
2. **Every money object snapshots its price** — list price, offered price,
   accepted price, invoice price are separate immutable fields.
3. **Append-only ledgers** — expenses, payouts, and payments are rows that are
   written once; corrections are new rows, never edits.
4. **Event-driven payouts** — the team only gets paid when a revenue event
   happens, and only after the client has actually paid (cash-flow guard).
5. **"Free" tools still cost money** — electricity, WiFi, and depreciation are
   allocated onto projects by tracked hours, so true margin is always visible.
6. **Branches are data, not deployments** — multi-branch clients (e.g. a
   carwash with 15 branches) are rows with `(business_id, branch_id)` scoping,
   not separate servers.

---

## Module map

```
┌─ LEADS & MARKETING ─── Google Maps finds, campaigns reach out, attribution closes the loop
│  ┌─ DEMOS ──────────── demo repos auto-built from templates, short links, view tracking
│  ┌─ PROPOSALS ──────── list 5k → offered 3k, tracked links, negotiation history
▼  ▼
CLIENTS ──► SALES ──► INVOICING & PAYMENTS ──► SUBSCRIPTIONS (maintenance MRR)
              │                                        │
              ▼                                        ▼
         PROJECTS & TICKETS ◄──── UPSELL MATRIX ◄───────┘
              │         (owns software, no website → opportunity)
              ▼
         TIME & PAYOUTS ◄─── comp plans (500 delivery + 100/mo support)
              │
              ▼
    TRUE MARGIN = revenue − payouts − tools − utilities − ads
```

| # | Doc | Module |
|---|-----|--------|
| 01 | [Architecture](docs/01-architecture.md) | Stack, principles, repo layout |
| 02 | [Catalogue & GitHub](docs/02-catalogue-github.md) | Template sync, demo repos, webhooks |
| 03 | [Leads & Campaigns](docs/03-leads-campaigns.md) | Lead intake, outreach sequences, attribution |
| 04 | [Demos & Proposals](docs/04-demos-proposals.md) | Demo lifecycle, price snapshots, negotiation |
| 05 | [Clients & Projects](docs/05-clients-projects.md) | Client 360, tickets, upsell opportunities |
| 06 | [Invoicing & Payments](docs/06-invoicing-payments.md) | Invoices, subscriptions, payment links |
| 07 | [Team Payouts](docs/07-team-payouts.md) | Comp plans, blocked→payable payout ledger |
| 08 | [Assets](docs/08-assets.md) | 5-laptop register, maintenance, depreciation |
| 09 | [Multi-Branch](docs/09-multi-branch.md) | Carwash 15-branch schema & scoping rules |
| 10 | [Cost Allocation](docs/10-cost-allocation.md) | Tools, utilities, true per-client margin |
| 11 | [Code & Client Repos](docs/11-code-client-repos.md) | Repo-per-client, deploy=tag, template update PRs |
| 12 | [Custom Projects](docs/12-custom-projects-procurement.md) | full_build budgets, hardware POs, client devices |
| 13 | [Investors & Funding](docs/13-investors-funding.md) | Rounds, restricted cash, waterfall payouts |
| 14 | [Module Add-ons](docs/14-module-add-ons.md) | AI-assisted builds, build specs, flat team fees |
| 15 | [Integrations & Credentials](docs/15-integrations-credentials.md) | Client-owned accounts, AES-256-GCM vault, three money lanes |
| 16 | [Deployment Matrix](docs/16-deployment-matrix.md) | Vercel / Hostinger / PaaS / office VPS pull-agent, one pipeline |
| 17 | [Service Schema Reuse](docs/17-service-schema-reuse.md) | Attributes/variants/values engine for quoting; forbidden in ledgers |
| 18 | [Solo Mode](docs/18-solo-mode.md) | Owner-only operation; WhatsApp/email message pipeline; portals deferred |

The consolidated narrative is in **[PROJECT_PLAN.md](PROJECT_PLAN.md)** and the
full DDL in **[schema/schema.sql](schema/schema.sql)**.

---

## Stack

| Layer | Choice |
|---|---|
| Frontend | React 19 + Vite 7 + Tailwind CSS 4, TanStack Query |
| Backend | Hono v4 + TypeScript, Zod schemas shared end-to-end |
| DB | Drizzle ORM + SQLite (better-sqlite3) → Postgres later |
| GitHub | GitHub App (per-repo install) + webhooks + cron sync |
| Payments | Tap / Moyasar payment links (no ZATCA) |
| QA | Vitest + Playwright, oxlint brand-token rules |

---

## Roadmap

- **MVP (2 weeks):** catalogue sync + clients + sales + invoices (manual line items)
- **v1:** leads/campaigns, demos, proposals, conversion flow
- **v1.5:** team payouts, assets, cost allocation
- **v2:** multi-branch product schema, upsell rules engine, client portal
