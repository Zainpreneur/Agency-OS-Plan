# 11 — Code & Client Repos (where client code lives)

## Repo-per-client, one org, strict convention

```
github.com/Zainpreneur/
├── Laundry-Business-Software-        ← TEMPLATE (the product)
├── demo-alnoor                       ← demo (auto-archived after conversion)
└── client-alnoor-website             ← THEIR code, forever
       ├── main                        ← protected; only PRs merge
       ├── develop                     ← staging
       ├── .client.yaml               ← {client_id, tier, maintenance_since}
       └── tags: v1.0 (launch) · v1.1 (added delivery page) …
```

**Rules**

- **Private repo per client**, created at conversion — never branches of a
  shared repo; one client's edits can't leak into another's site
- **Deploy = tag**: every live deploy tags `vX.Y` → "what's running in
  production" is a git fact, not a memory
- **Hosting per template type** (Pages/Netlify/Vercel), deploy hook wired to
  `main` — merge = deploy; the `deployment` webhook logs it to the client's
  project timeline
- **Staging branch** for anything non-trivial: client approves on the
  `develop` URL → merge → live
- `.client.yaml` is the join key back to the Agency OS (client_id, tier)

## The update workflow

```
WhatsApp: "change my opening hours to 10pm"
  → ticket (type: maintenance, minutes from the 4h/mo retainer bucket)
  → branch fix/hours-alnoor → commit → PR → deploy (4 min)
  → PR merge auto-comments on the ticket: "live at 14:32 ✓"
```

- Small covered changes: straight from the ticket, no ceremony
- **Change requests** (new page/feature) → mini-proposal with snapshot
  pricing → accepted → branch → PR → invoice line + payout accrual
- **Hotfix path:** direct push to main + PR-after + client ping

## Maintenance-subscriber update PRs (churn defense)

When the upstream **template** improves (new booking widget), a job diffs
template releases against each maintenance client's repo and opens a
**ready-to-merge update PR**. The 200–300/mo visibly buys "the product keeps
getting better" — zero extra labor.

## Schema

```sql
client_repos (id, client_id, project_id, repo_name UNIQUE,
              kind [website|custom_software],
              default_branch 'main', staging_branch 'develop',
              hosting, deploy_hook, live_tag,          -- v1.4 in production
              github_app_installed, last_synced_at)

update_pull_requests (id, client_repo_id,
              kind [template_update|change_request|hotfix],
              source_ref,                              -- template release tag
              title, pr_number, status [open|merged|closed],
              opened_at, merged_at)
```
