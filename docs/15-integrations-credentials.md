# 15 — Integrations & Credential Vault (client-owned accounts)

## Core philosophy: "Client owns the world, you hold the keys"

Every account, subscription, and card is created **under the client's
identity**. Your agency's cards never touch a client project.

- Provision *their* Airtable/Formaloo/Meta via their given Google OAuth —
  all billed to *their* card on file
- You hold scoped, revocable, encrypted access — never ownership
- Offboarding = revoke your tokens; their accounts keep living
- **Card rule:** never store card numbers (PCI scope). Cards live only in
  providers' own vaults. Purchases for clients go through a Tap/Moyasar
  payment link or direct vendor entry. DB stores tokens + receipts only.

## Credential vault (the only place secrets live)

```sql
credentials (id, client_id, project_id, provider,        -- google|airtable|formaloo|meta|vercel|ssh
             kind [oauth_token|api_key|ssh_key|service_account],
             ciphertext, iv, auth_tag,                    -- AES-256-GCM; key from env, never in DB
             scopes,                                      -- least privilege
             expires_at, last_rotated, status [active|revoked], last_used_at)
audit_log   (id, actor, action, entity, entity_id, at)    -- every secret READ is logged
```

## Connector layer (you choose, they never hear "API")

| Their words | Your choice | Billed to |
|---|---|---|
| "tables for livestock & suppliers" | Airtable | their card |
| "booking & inquiry forms" | Formaloo | their card |
| "message customers on WhatsApp" | WhatsApp Cloud API (their Meta + phone) | their card |
| "sign in with Google" | Google OAuth | free |

```sql
connector_catalog  (provider, category [tables|forms|messaging|auth|hosting],
                    auth_type, pricing_model, owned_by [client|agency], selection_notes)
project_connectors (id, client_id, project_id, credential_id,
                    status [requested|provisioned|connected|broken],
                    provisioned_at, external_ref, last_healthcheck_at)
```

Daily health cron: token valid? quota OK? plan changed? A broken WhatsApp
token becomes a ticket **before** the client notices.

## Three money lanes

| Lane | Who pays | Treatment |
|---|---|---|
| A — Your revenue | Client → you | Dev-fee invoice **only after deployment accepted**; hardware = PO + invoice line |
| B — Client's own SaaS | Client → providers (their card) | **Track, never bill**: `external_client_costs` |
| C — Your SaaS products | Client → you, recurring | Existing subscriptions engine |

```sql
external_client_costs (id, client_id, project_id, provider, plan,
                       amount, currency, billing_day,
                       status [active|downgraded|cancelled],
                       renewal_notice_sent_at)   -- cron pings CLIENT, not your card
```

Portal shows: *"Your monthly services: Airtable $20 · Formaloo $15 = $43/mo
to your card"* — flagged `owned_by: client` everywhere so margin reports
never mix their costs with yours.

## Codebase ownership policy

- Default: **agency org**, private repo per client (you run maintenance)
- `client_repos.repo_policy [agency_held|shared|transferred]`, flips on
  final payment → auto collaborator invite / transfer offer (no hostage)
- **Data & accounts are theirs unconditionally; code is yours until paid**

## Offboarding (revoke-all checklist)

Revoke every vault row + provider-side revoke endpoints; archive repos per
policy; export client data; close `external_client_costs` advisories.
A 5-minute mechanical task because everything was vault-referenced.
