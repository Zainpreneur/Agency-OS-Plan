# 01 — Architecture

## Stack (per `Zainpreneur/tech-stacks`)

| Layer | Choice | Notes |
|---|---|---|
| UI | React 19 + Vite 7 | Instant HMR, editorial brand aesthetic |
| Styling | Tailwind CSS 4 | Tokens from Zod schema; no rogue hex (oxlint rule) |
| Data fetching | TanStack Query | Caching/sync for the boards & timelines |
| API | Hono v4 + TypeScript | Web-standard APIs, built-in OpenAPI/zod validation |
| ORM | Drizzle + better-sqlite3 | Type-safe SQL; Postgres migration path is painless |
| Validation | Zod | One schema validates API, forms, and DB types |
| Jobs | cron in `node --watch` | Upgrade to a queue only when webhooks outgrow it |
| Auth | Session-based | Single-user first; team members as rows |
| QA | Vitest + Playwright + oxlint | Brand-token enforcement in CI |

## Application layout

```
agency-os/
├── src/
│   ├── server/
│   │   ├── routes/          # Hono routers (leads, campaigns, demos, …)
│   │   ├── services/        # business logic (convert-to-client, payout runs)
│   │   ├── jobs/            # cron: sync, sender, renewals, allocations
│   │   └── db/schema.ts     # Drizzle schema (single source of truth)
│   ├── web/                 # React app
│   └── shared/zod/          # schemas shared by server + web
├── drizzle/                 # migrations
└── tests/
```

## Cross-cutting design principles

1. **GitHub is the product database.** Never hand-enter repo facts; sync them.
2. **Price snapshots.** `list_price / offered_price / accepted_price /
   unit_price` are separate immutable fields. A future price change never
   rewrites a proposal, invoice, or sales history.
3. **Append-only ledgers.** `expenses`, `tool_charges`, `payouts`,
   `payments`, `lead_activities`, `github_events` are written once.
   Corrections are new rows (`kind='adjustment'` with a reason).
4. **Event-driven money.** Payouts accrue only when a revenue event fires,
   and stay `blocked` until the matching client payment exists.
5. **Query-layer scoping.** Tenancy and branch scope are enforced in SQL
   (`WHERE business_id = ?`), never only in the frontend.
6. **Denormalize keys, snapshot names.** Store `business_id`/`branch_id`
   everywhere; snapshot display names only onto printed documents.
7. **Honest cost accounting.** Every project carries its share of tools,
   utilities, and depreciation via tracked hours — "free" never means free.

## Environment

```
DATABASE_URL, PORT, NODE_ENV
GITHUB_APP_ID, GITHUB_PRIVATE_KEY, GITHUB_WEBHOOK_SECRET
TAP_SECRET_KEY / MOYASAR_SECRET_KEY
BASE_URL            # for short links: yourdomain.d/r/:code
```

## CI (GitHub Actions)

`npm install → lint → tsc --noEmit → test → verify:all → deploy dist`
Repos created for demos use the same template-promotion pipeline.
