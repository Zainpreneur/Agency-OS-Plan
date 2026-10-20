-- ============================================================================
-- AGENCY OS — consolidated schema
-- SQLite-flavored DDL (maps 1:1 to Drizzle definitions)
-- Sections: catalogue · leads/campaigns · demos/proposals · clients/sales
--           invoicing/subscriptions · projects/tickets/time · payouts
--           assets · costs · multi-branch product · infra
-- ============================================================================

-- ── CATALOGUE (mirrored from GitHub) ───────────────────────────────────────
CREATE TABLE templates (
  id            INTEGER PRIMARY KEY,
  repo_name     TEXT NOT NULL UNIQUE,          -- Laundry-Business-Software
  slug          TEXT NOT NULL,
  name          TEXT NOT NULL,
  category      TEXT NOT NULL,                 -- business_software | website | addon
  list_price    REAL NOT NULL,                 -- snapshot source for proposals
  tier          TEXT NOT NULL DEFAULT 'standard',
  latest_tag    TEXT,                          -- sellable version (from releases)
  demo_url      TEXT,
  topics_json   TEXT,
  active        INTEGER NOT NULL DEFAULT 1,
  synced_at     TEXT
);

CREATE TABLE github_events (                    -- idempotent webhook inbox
  delivery_id   TEXT PRIMARY KEY,
  event         TEXT NOT NULL,
  repo_name     TEXT,
  payload       TEXT NOT NULL,
  processed_at  TEXT
);

-- ── LEADS & CAMPAIGNS ──────────────────────────────────────────────────────
CREATE TABLE leads (
  id                    INTEGER PRIMARY KEY,
  business_name         TEXT NOT NULL,
  contact_name          TEXT, phone TEXT, email TEXT,
  source                TEXT NOT NULL,          -- google_maps | referral | inbound …
  source_url            TEXT,
  industry              TEXT, city TEXT, lat TEXT, lng TEXT,
  has_website           INTEGER,               -- NULL unknown, 0 = upsell signal
  status                TEXT NOT NULL DEFAULT 'discovered',
                       -- discovered|contacted|demo_built|demo_shared|
                       -- proposal_sent|negotiating|won|lost|archived
  first_campaign_id     INTEGER REFERENCES campaigns(id),
  first_touch_at        TEXT,
  converting_campaign_id INTEGER REFERENCES campaigns(id),
  touch_count           INTEGER NOT NULL DEFAULT 0,
  assigned_to           TEXT,
  next_follow_up_at     TEXT,
  lost_reason           TEXT,                  -- price|no_response|diying|bad_fit
  created_at            TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at            TEXT
);
CREATE INDEX idx_leads_status ON leads(status);
CREATE INDEX idx_leads_followup ON leads(next_follow_up_at);

CREATE TABLE lead_activities (                  -- append-only timeline
  id            INTEGER PRIMARY KEY,
  lead_id       INTEGER NOT NULL REFERENCES leads(id),
  type          TEXT NOT NULL,                  -- note|call|whatsapp|email|demo_opened|proposal_viewed
  campaign_id   INTEGER REFERENCES campaigns(id),
  content       TEXT,
  occurred_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE campaigns (
  id              INTEGER PRIMARY KEY,
  name            TEXT NOT NULL,                -- "Furniture Stores — Oct 2026"
  kind            TEXT NOT NULL,                -- email_blast|whatsapp_blast|cold_call|ads|referral
  industry_focus  TEXT,
  message_variant TEXT,                         -- A|B
  budget          REAL, spend REAL DEFAULT 0,
  status          TEXT NOT NULL DEFAULT 'draft',-- draft|running|paused|done
  started_at      TEXT, ends_at TEXT
);

CREATE TABLE campaign_targets (                 -- campaign × lead × step
  id            INTEGER PRIMARY KEY,
  campaign_id   INTEGER NOT NULL REFERENCES campaigns(id),
  lead_id       INTEGER NOT NULL REFERENCES leads(id),
  step_no       INTEGER NOT NULL DEFAULT 0,
  channel       TEXT NOT NULL,                  -- email|whatsapp|sms|call
  status        TEXT NOT NULL DEFAULT 'scheduled',
                -- scheduled|sending|sent|delivered|failed|skipped
  scheduled_at  TEXT, sent_at TEXT,
  message_body  TEXT,                           -- RENDERED — stored for audit
  UNIQUE (campaign_id, lead_id, step_no)
);
CREATE INDEX idx_targets_due ON campaign_targets(status, scheduled_at);

CREATE TABLE sequence_steps (
  campaign_id   INTEGER NOT NULL REFERENCES campaigns(id),
  step_no       INTEGER NOT NULL,
  channel       TEXT NOT NULL,
  delay_days    INTEGER NOT NULL,
  template      TEXT NOT NULL,                  -- {{business_name}} etc.
  action_if     TEXT DEFAULT 'none',            -- none|stop_on_reply
  PRIMARY KEY (campaign_id, step_no)
);

-- ── DEMOS ──────────────────────────────────────────────────────────────────
CREATE TABLE demos (
  id              INTEGER PRIMARY KEY,
  lead_id         INTEGER REFERENCES leads(id),
  client_id       INTEGER REFERENCES clients(id),   -- upsell demos
  template_id     INTEGER NOT NULL REFERENCES templates(id),
  repo_name       TEXT NOT NULL,
  repo_url        TEXT, github_pages_url TEXT,
  short_link      TEXT UNIQUE,                  -- /d/:code → records demo_opened
  status          TEXT NOT NULL DEFAULT 'building', -- building|live|archived
  built_at        TEXT, expires_at TEXT,
  view_count      INTEGER NOT NULL DEFAULT 0,
  last_viewed_at  TEXT
);

-- ── PROPOSALS (price snapshots) ────────────────────────────────────────────
CREATE TABLE proposals (
  id              INTEGER PRIMARY KEY,
  proposal_no     TEXT NOT NULL UNIQUE,         -- PROP-2026-014
  lead_id         INTEGER REFERENCES leads(id),
  client_id       INTEGER REFERENCES clients(id),   -- warm upsell proposals
  demo_id         INTEGER REFERENCES demos(id),
  template_id     INTEGER REFERENCES templates(id),
  list_price      REAL NOT NULL,                -- snapshot — never edited
  offered_price   REAL NOT NULL,
  discount_reason TEXT,
  accepted_price  REAL,
  status          TEXT NOT NULL DEFAULT 'draft',-- draft|sent|viewed|accepted|rejected|expired
  valid_until     TEXT, accepted_at TEXT,
  sent_via_link   TEXT
);

CREATE TABLE proposal_lines (
  id            INTEGER PRIMARY KEY,
  proposal_id   INTEGER NOT NULL REFERENCES proposals(id),
  kind          TEXT NOT NULL,                  -- website_build|maintenance|addon|customization
  description   TEXT NOT NULL,
  qty           REAL NOT NULL DEFAULT 1,
  unit_price    REAL NOT NULL                   -- snapshot
);

-- ── CLIENTS & SALES ────────────────────────────────────────────────────────
CREATE TABLE clients (
  id            INTEGER PRIMARY KEY,
  lead_id       INTEGER UNIQUE REFERENCES leads(id),  -- set at conversion
  name          TEXT NOT NULL,
  contact_name  TEXT, email TEXT, phone TEXT,
  vat_number    TEXT, country TEXT DEFAULT 'SA',
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE sales (
  id            INTEGER PRIMARY KEY,
  client_id     INTEGER NOT NULL REFERENCES clients(id),
  template_id   INTEGER REFERENCES templates(id),
  proposal_id   INTEGER REFERENCES proposals(id),
  tier          TEXT NOT NULL DEFAULT 'single', -- single|multi_branch|enterprise
  price_model   TEXT DEFAULT 'one_time',        -- one_time|per_branch|saas
  price         REAL NOT NULL,
  branch_count  INTEGER DEFAULT 1,
  delivery_repo TEXT,
  won_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ── INVOICING, PAYMENTS, SUBSCRIPTIONS ─────────────────────────────────────
CREATE TABLE invoices (
  id            INTEGER PRIMARY KEY,
  invoice_no    TEXT NOT NULL UNIQUE,           -- INV-2026-0042
  client_id     INTEGER NOT NULL REFERENCES clients(id),
  sale_id       INTEGER REFERENCES sales(id),
  status        TEXT NOT NULL DEFAULT 'draft',  -- draft|sent|viewed|paid|overdue|void
  subtotal      REAL NOT NULL DEFAULT 0,
  vat           REAL NOT NULL DEFAULT 0,
  total         REAL NOT NULL DEFAULT 0,
  due_at        TEXT, paid_at TEXT,
  payment_link  TEXT
);

CREATE TABLE invoice_lines (
  id            INTEGER PRIMARY KEY,
  invoice_id    INTEGER NOT NULL REFERENCES invoices(id),
  description   TEXT NOT NULL,
  ticket_id     INTEGER,                        -- "Custom: delivery tracking page"
  deployment_id INTEGER,                        -- "Branch 07 setup fee"
  qty           REAL NOT NULL DEFAULT 1,
  unit_price    REAL NOT NULL                   -- snapshot
);

CREATE TABLE payments (                          -- written by webhooks only
  id            INTEGER PRIMARY KEY,
  invoice_id    INTEGER NOT NULL REFERENCES invoices(id),
  provider      TEXT NOT NULL,                  -- tap|moyasar|bank
  external_id   TEXT UNIQUE,
  amount        REAL NOT NULL,
  paid_at       TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE subscriptions (                     -- REVENUE recurring (MRR)
  id              INTEGER PRIMARY KEY,
  client_id       INTEGER NOT NULL REFERENCES clients(id),
  sale_id         INTEGER REFERENCES sales(id),
  name            TEXT NOT NULL,                -- "Website maintenance"
  amount          REAL NOT NULL,
  interval        TEXT NOT NULL DEFAULT 'monthly',
  status          TEXT NOT NULL DEFAULT 'active',-- active|paused|cancelled
  started_at      TEXT NOT NULL DEFAULT (datetime('now')),
  next_invoice_at TEXT,
  cancelled_at    TEXT
);

-- ── PROJECTS, TICKETS, TIME, OPPORTUNITIES ─────────────────────────────────
CREATE TABLE projects (
  id            INTEGER PRIMARY KEY,
  client_id     INTEGER NOT NULL REFERENCES clients(id),
  sale_id       INTEGER REFERENCES sales(id),
  github_repo   TEXT,
  scope         TEXT,
  status        TEXT NOT NULL DEFAULT 'planned',-- planned|in_progress|delivered|on_hold
  budget        REAL,
  assignee      TEXT,
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE tickets (
  id             INTEGER PRIMARY KEY,
  client_id      INTEGER NOT NULL REFERENCES clients(id),
  project_id     INTEGER REFERENCES projects(id),
  opportunity_id INTEGER,                       -- set when ticket becomes a lead
  deployment_id  INTEGER,                       -- multi-branch: which branch
  github_issue   INTEGER,
  type           TEXT NOT NULL DEFAULT 'support',-- customization|support|bug|feature_request
  priority       TEXT DEFAULT 'normal',
  status         TEXT NOT NULL DEFAULT 'open',  -- open|in_progress|waiting|closed
  subject        TEXT, body TEXT,
  opened_at      TEXT NOT NULL DEFAULT (datetime('now')),
  closed_at      TEXT
);

CREATE TABLE time_entries (
  id          INTEGER PRIMARY KEY,
  project_id  INTEGER REFERENCES projects(id),
  ticket_id   INTEGER REFERENCES tickets(id),
  team_member_id INTEGER,                       -- who
  device_id   INTEGER REFERENCES assets(id),    -- which laptop
  minutes     INTEGER NOT NULL,
  billable    INTEGER NOT NULL DEFAULT 1,
  rate        REAL,
  worked_at   TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_time_project ON time_entries(project_id, worked_at);

CREATE TABLE opportunities (
  id                  INTEGER PRIMARY KEY,
  client_id           INTEGER NOT NULL REFERENCES clients(id),
  kind                TEXT NOT NULL,            -- gap_upsell|expansion|renewal|risk
  reason              TEXT NOT NULL,            -- "owns software, no website"
  reason_detail       TEXT,                     -- "asked about inventory (ticket 47)"
  suggested_template_id INTEGER REFERENCES templates(id),
  detected_by         TEXT NOT NULL DEFAULT 'rule', -- rule|ticket|manual
  status              TEXT NOT NULL DEFAULT 'identified',
                      -- identified|demo_built|proposed|won|dismissed
  priority            TEXT DEFAULT 'warm',      -- hot|warm|cold
  proposal_id         INTEGER REFERENCES proposals(id),
  won_sale_id         INTEGER REFERENCES sales(id),
  dismissed_reason    TEXT,
  opened_at           TEXT NOT NULL DEFAULT (datetime('now')),
  next_action_at      TEXT, closed_at TEXT
);

CREATE TABLE upsell_rules (
  id                    INTEGER PRIMARY KEY,
  has_category          TEXT NOT NULL,          -- 'business_software'
  missing_category      TEXT NOT NULL,          -- 'website'
  suggested_template_id INTEGER REFERENCES templates(id),
  active                INTEGER NOT NULL DEFAULT 1
);

-- ── TEAM PAYOUTS ───────────────────────────────────────────────────────────
CREATE TABLE team_members (
  id         INTEGER PRIMARY KEY,
  name       TEXT NOT NULL,
  phone      TEXT,
  pay_model  TEXT NOT NULL DEFAULT 'revenue_share', -- revenue_share|fixed|hourly
  status     TEXT NOT NULL DEFAULT 'active',        -- active|offboarded
  joined_at  TEXT
);

CREATE TABLE comp_plans (
  id              INTEGER PRIMARY KEY,
  team_member_id  INTEGER NOT NULL REFERENCES team_members(id),
  applies_to      TEXT,                        -- template category, e.g. 'website'
  kind            TEXT NOT NULL,               -- delivery_fee|milestone|monthly_support|bonus
  amount          REAL NOT NULL,
  trigger         TEXT NOT NULL,               -- sale_won|invoice_paid|delivered|subscription_active
  active          INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE payouts (
  id                  INTEGER PRIMARY KEY,
  team_member_id      INTEGER NOT NULL REFERENCES team_members(id),
  client_id           INTEGER REFERENCES clients(id),
  sale_id             INTEGER REFERENCES sales(id),
  subscription_id     INTEGER REFERENCES subscriptions(id),
  comp_plan_id        INTEGER REFERENCES comp_plans(id),
  kind                TEXT NOT NULL,           -- delivery|milestone|monthly_support|bonus|adjustment
  amount              REAL NOT NULL,
  status              TEXT NOT NULL DEFAULT 'accrued',
                      -- accrued|blocked|payable|paid|cancelled
  accrued_at          TEXT NOT NULL DEFAULT (datetime('now')),
  unblock_payment_id  INTEGER REFERENCES payments(id),  -- cash-flow guard
  payable_at          TEXT, paid_at TEXT, paid_via TEXT,
  notes               TEXT
);
CREATE INDEX idx_payouts_status ON payouts(status);

-- ── ASSETS ─────────────────────────────────────────────────────────────────
CREATE TABLE assets (
  id                   INTEGER PRIMARY KEY,
  asset_tag            TEXT NOT NULL UNIQUE,   -- ZP-LAP-01
  kind                 TEXT NOT NULL DEFAULT 'laptop',
  make                 TEXT, model TEXT, serial_no TEXT,
  os                   TEXT, specs_json        TEXT,
  purchase_date        TEXT, purchase_cost REAL, currency TEXT DEFAULT 'SAR',
  warranty_until       TEXT,
  depreciation_months  INTEGER DEFAULT 36,
  status               TEXT NOT NULL DEFAULT 'in_use',
                       -- in_use|in_repair|in_storage|retired|disposed
  condition            TEXT DEFAULT 'good',    -- good|fair|poor
  current_holder_id    INTEGER REFERENCES team_members(id),
  insurance_ref        TEXT, notes TEXT
);

CREATE TABLE asset_assignments (
  id                  INTEGER PRIMARY KEY,
  asset_id            INTEGER NOT NULL REFERENCES assets(id),
  holder_id           INTEGER NOT NULL REFERENCES team_members(id),
  assigned_at         TEXT NOT NULL DEFAULT (datetime('now')),
  returned_at         TEXT,                    -- NULL = currently held
  purpose             TEXT,
  condition_at_handover TEXT
);

CREATE TABLE maintenance_schedules (
  id           INTEGER PRIMARY KEY,
  asset_id     INTEGER NOT NULL REFERENCES assets(id),
  kind         TEXT NOT NULL,                  -- cleaning|battery_check|insurance|backup_verify…
  every_days   INTEGER NOT NULL,
  next_due_at  TEXT,
  owner_id     INTEGER REFERENCES team_members(id)
);

CREATE TABLE maintenance_logs (
  id              INTEGER PRIMARY KEY,
  asset_id        INTEGER NOT NULL REFERENCES assets(id),
  kind            TEXT NOT NULL,
  performed_at    TEXT NOT NULL DEFAULT (datetime('now')),
  performed_by    TEXT,
  cost_sar        REAL DEFAULT 0,
  vendor          TEXT, downtime_hours REAL,
  issue_reported  TEXT, resolution TEXT,
  invoice_url     TEXT
);

CREATE TABLE asset_licenses (                   -- tool seats on physical machines
  id             INTEGER PRIMARY KEY,
  asset_id       INTEGER NOT NULL REFERENCES assets(id),
  tool_cost_id   INTEGER NOT NULL REFERENCES tool_costs(id),
  seat_user      TEXT,
  activated_at   TEXT NOT NULL DEFAULT (datetime('now')),
  deactivated_at TEXT
);

CREATE TABLE disposals (
  id           INTEGER PRIMARY KEY,
  asset_id     INTEGER NOT NULL REFERENCES assets(id),
  date         TEXT NOT NULL,
  method       TEXT NOT NULL,                   -- sold|traded|donated|scrapped
  proceeds_sar REAL DEFAULT 0,
  buyer        TEXT, documents_url TEXT
);

-- ── COSTS (vendors, subscriptions, ledger, shared allocation) ──────────────
CREATE TABLE vendors (
  id       INTEGER PRIMARY KEY,
  name     TEXT NOT NULL,
  website  TEXT,
  category TEXT NOT NULL                        -- saas|utility|hardware|contractor|ads
);

CREATE TABLE tool_costs (                        -- COST recurring (subscriptions)
  id               INTEGER PRIMARY KEY,
  vendor_id        INTEGER REFERENCES vendors(id),
  name             TEXT NOT NULL,               -- "Claude Code"
  plan             TEXT, seats INTEGER,
  amount           REAL NOT NULL, currency TEXT NOT NULL DEFAULT 'SAR',
  sar_amount       REAL, fx_rate REAL,
  interval         TEXT NOT NULL DEFAULT 'monthly', -- monthly|yearly|one_time
  next_renewal_at  TEXT,
  status           TEXT NOT NULL DEFAULT 'active',  -- trial|active|paused|cancelled
  allocated_by     TEXT NOT NULL DEFAULT 'hours',   -- hours|flat|equal
  allocated_project_id INTEGER,                     -- for 'flat'
  cancel_url       TEXT, notes TEXT
);

CREATE TABLE tool_charges (                      -- actual renewals (cron-written)
  id            INTEGER PRIMARY KEY,
  tool_cost_id  INTEGER NOT NULL REFERENCES tool_costs(id),
  paid_at       TEXT NOT NULL DEFAULT (datetime('now')),
  amount        REAL NOT NULL, sar_amount REAL, fx_rate REAL,
  period_from   TEXT, period_to TEXT,
  receipt_url   TEXT
);

CREATE TABLE expenses (                          -- THE ledger: everything out
  id            INTEGER PRIMARY KEY,
  date          TEXT NOT NULL,
  vendor_id     INTEGER REFERENCES vendors(id),
  kind          TEXT NOT NULL,                  -- subscription|utility|hardware|contractor|ads|office|other
  description   TEXT NOT NULL,
  amount        REAL NOT NULL, currency TEXT DEFAULT 'SAR', sar_amount REAL,
  tool_cost_id  INTEGER REFERENCES tool_costs(id),
  project_id    INTEGER, client_id INTEGER,     -- direct cost if identifiable
  receipt_url   TEXT, payment_method TEXT, notes TEXT
);
CREATE INDEX idx_expenses_month ON expenses(date, kind);

CREATE TABLE shared_costs (                      -- utilities + depreciation
  id           INTEGER PRIMARY KEY,
  month        TEXT NOT NULL,                   -- '2026-10'
  kind         TEXT NOT NULL,                   -- electricity|wifi|rent|device_depreciation
  total_sar    REAL NOT NULL,
  allocation   TEXT NOT NULL DEFAULT 'hours',   -- hours|equal
  allocations_json TEXT                         -- {projectId: amount, …}
);
CREATE UNIQUE INDEX idx_shared_month_kind ON shared_costs(month, kind);

-- ── MULTI-BRANCH PRODUCT SCHEMA (what you SELL, e.g. carwash) ─────────────
-- Agency OS side of deployments:
CREATE TABLE deployments (
  id               INTEGER PRIMARY KEY,
  sale_id          INTEGER NOT NULL REFERENCES sales(id),
  client_id        INTEGER NOT NULL REFERENCES clients(id),
  branch_label     TEXT NOT NULL,               -- "Branch 07 — Corniche"
  city             TEXT,
  status           TEXT NOT NULL DEFAULT 'sold',-- sold|config|data_import|training|live|suspended
  planned_go_live  TEXT, actual_go_live TEXT,
  contact_name     TEXT, contact_phone TEXT,
  notes            TEXT
);

-- The carwash product's own database (separate app, same pattern):
CREATE TABLE cw_businesses (
  id         INTEGER PRIMARY KEY,
  name       TEXT NOT NULL,
  currency   TEXT DEFAULT 'SAR', timezone TEXT,
  tax_rate   REAL DEFAULT 0, settings_json TEXT
);

CREATE TABLE cw_branches (
  id             INTEGER PRIMARY KEY,
  business_id    INTEGER NOT NULL REFERENCES cw_businesses(id),
  code           TEXT NOT NULL, name TEXT NOT NULL,
  address        TEXT, city TEXT, lat TEXT, lng TEXT, phone TEXT,
  manager_user_id INTEGER,
  status         TEXT NOT NULL DEFAULT 'planned', -- planned|setup|live|suspended
  settings_json  TEXT
);

CREATE TABLE cw_devices (                        -- POS tablet pinned to branch
  id           INTEGER PRIMARY KEY,
  business_id  INTEGER NOT NULL,
  branch_id    INTEGER NOT NULL REFERENCES cw_branches(id),
  label        TEXT, kind TEXT DEFAULT 'pos',
  last_seen_at TEXT
);

CREATE TABLE cw_users (
  id            INTEGER PRIMARY KEY,
  email         TEXT NOT NULL UNIQUE,
  name          TEXT, password_hash TEXT
);

CREATE TABLE cw_memberships (                    -- branch-scoped RBAC
  id           INTEGER PRIMARY KEY,
  user_id      INTEGER NOT NULL REFERENCES cw_users(id),
  business_id  INTEGER NOT NULL,
  branch_id    INTEGER REFERENCES cw_branches(id), -- NULL = ALL branches (owner)
  role         TEXT NOT NULL                      -- owner|manager|cashier|washer
);

CREATE TABLE cw_services (                       -- business-level price list
  id           INTEGER PRIMARY KEY,
  business_id  INTEGER NOT NULL,
  name         TEXT NOT NULL, category TEXT,
  base_price   REAL NOT NULL, duration_min INTEGER,
  active       INTEGER DEFAULT 1
);

CREATE TABLE cw_branch_services (                 -- branch price overrides
  branch_id    INTEGER NOT NULL REFERENCES cw_branches(id),
  service_id   INTEGER NOT NULL REFERENCES cw_services(id),
  price        REAL, duration_min INTEGER, active INTEGER,
  PRIMARY KEY (branch_id, service_id)
);

CREATE TABLE cw_customers (                       -- SHARED across branches
  id           INTEGER PRIMARY KEY,
  business_id  INTEGER NOT NULL,
  full_name    TEXT NOT NULL, phone TEXT, email TEXT, notes TEXT
);

CREATE TABLE cw_vehicles (                        -- SHARED — the car follows
  id           INTEGER PRIMARY KEY,
  business_id  INTEGER NOT NULL,
  customer_id  INTEGER NOT NULL REFERENCES cw_customers(id),
  plate_no     TEXT NOT NULL, make TEXT, model TEXT, color TEXT
);

CREATE TABLE cw_bookings (
  id           INTEGER PRIMARY KEY,
  business_id  INTEGER NOT NULL,
  branch_id    INTEGER NOT NULL REFERENCES cw_branches(id),
  customer_id  INTEGER NOT NULL, vehicle_id INTEGER NOT NULL,
  slot_start   TEXT, slot_end TEXT,
  status       TEXT NOT NULL DEFAULT 'booked',
  source       TEXT NOT NULL DEFAULT 'walk_in'   -- walk_in|app|phone
);

CREATE TABLE cw_work_orders (
  id           INTEGER PRIMARY KEY,
  business_id  INTEGER NOT NULL,
  branch_id    INTEGER NOT NULL REFERENCES cw_branches(id),
  booking_id   INTEGER REFERENCES cw_bookings(id),
  customer_id  INTEGER NOT NULL, vehicle_id INTEGER NOT NULL,
  status       TEXT NOT NULL DEFAULT 'queued',   -- queued|washing|qc|ready|delivered|cancelled
  subtotal REAL DEFAULT 0, discount REAL DEFAULT 0, total REAL DEFAULT 0,
  opened_at    TEXT NOT NULL DEFAULT (datetime('now')),
  completed_at TEXT, delivered_by INTEGER
);

CREATE TABLE cw_work_order_items (
  work_order_id INTEGER NOT NULL REFERENCES cw_work_orders(id),
  service_id    INTEGER NOT NULL,
  qty           REAL NOT NULL DEFAULT 1,
  unit_price    REAL NOT NULL,                   -- SNAPSHOT
  PRIMARY KEY (work_order_id, service_id)
);

CREATE TABLE cw_staff (
  id           INTEGER PRIMARY KEY,
  business_id  INTEGER NOT NULL,
  employee_no  TEXT, name TEXT, skills TEXT
);

CREATE TABLE cw_staff_branches (
  staff_id  INTEGER NOT NULL REFERENCES cw_staff(id),
  branch_id INTEGER NOT NULL REFERENCES cw_branches(id),
  PRIMARY KEY (staff_id, branch_id)
);

CREATE TABLE cw_shifts (
  id             INTEGER PRIMARY KEY,
  business_id    INTEGER NOT NULL,
  branch_id      INTEGER NOT NULL REFERENCES cw_branches(id),
  opened_by      INTEGER, opened_at TEXT,
  closed_by      INTEGER, closed_at TEXT,
  opening_float REAL DEFAULT 0, counted_cash REAL
);

CREATE TABLE cw_payments (
  id            INTEGER PRIMARY KEY,
  business_id   INTEGER NOT NULL,
  branch_id     INTEGER NOT NULL REFERENCES cw_branches(id),
  work_order_id INTEGER, shift_id INTEGER,
  method        TEXT NOT NULL DEFAULT 'cash',    -- cash|card|transfer|online
  amount        REAL NOT NULL,
  paid_at       TEXT NOT NULL DEFAULT (datetime('now')),
  external_ref  TEXT
);

CREATE TABLE cw_daily_branch_sales (             -- rollups → HQ dashboard O(15)
  branch_id     INTEGER NOT NULL REFERENCES cw_branches(id),
  business_date TEXT NOT NULL,
  gross REAL DEFAULT 0, discounts REAL DEFAULT 0, net REAL DEFAULT 0,
  cars_count INTEGER DEFAULT 0, avg_ticket REAL,
  PRIMARY KEY (branch_id, business_date)
);

CREATE TABLE cw_products (
  id        INTEGER PRIMARY KEY,
  business_id INTEGER NOT NULL,
  sku TEXT, name TEXT, unit TEXT, cost REAL
);

CREATE TABLE cw_inventory_moves (
  id          INTEGER PRIMARY KEY,
  business_id INTEGER NOT NULL,
  branch_id   INTEGER NOT NULL REFERENCES cw_branches(id),
  product_id  INTEGER NOT NULL REFERENCES cw_products(id),
  qty_delta   REAL NOT NULL,
  reason      TEXT NOT NULL,                     -- purchase|usage|transfer|adjust
  ref_id      INTEGER,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ══ V2 (docs 11–14): code lifecycle, procurement, funding, add-ons ═════════

-- ── CLIENT REPOS (where client code lives) ─────────────────────────────────
CREATE TABLE client_repos (
  id                  INTEGER PRIMARY KEY,
  client_id           INTEGER NOT NULL REFERENCES clients(id),
  project_id          INTEGER REFERENCES projects(id),
  repo_name           TEXT NOT NULL UNIQUE,      -- client-alnoor-website
  kind                TEXT NOT NULL DEFAULT 'website', -- website|custom_software
  default_branch      TEXT NOT NULL DEFAULT 'main',
  staging_branch      TEXT NOT NULL DEFAULT 'develop',
  hosting             TEXT, deploy_hook TEXT,
  live_tag            TEXT,                      -- v1.4 currently in production
  github_app_installed INTEGER NOT NULL DEFAULT 0,
  last_synced_at      TEXT
);

CREATE TABLE update_pull_requests (               -- template→client update PRs
  id             INTEGER PRIMARY KEY,
  client_repo_id INTEGER NOT NULL REFERENCES client_repos(id),
  kind           TEXT NOT NULL,                   -- template_update|change_request|hotfix
  source_ref     TEXT,                            -- template release tag
  title          TEXT, pr_number INTEGER,
  status         TEXT NOT NULL DEFAULT 'open',    -- open|merged|closed
  opened_at      TEXT NOT NULL DEFAULT (datetime('now')),
  merged_at      TEXT
);

-- ── PROCUREMENT (custom projects, hardware) ────────────────────────────────
CREATE TABLE purchase_orders (
  id           INTEGER PRIMARY KEY,
  project_id   INTEGER NOT NULL REFERENCES projects(id),
  vendor_id    INTEGER REFERENCES vendors(id),
  kind         TEXT NOT NULL DEFAULT 'hardware',  -- hardware|services
  total        REAL NOT NULL DEFAULT 0,
  status       TEXT NOT NULL DEFAULT 'draft',     -- draft|ordered|received|installed|invoiced
  ordered_at   TEXT, received_at TEXT
);

CREATE TABLE purchase_items (
  id          INTEGER PRIMARY KEY,
  po_id       INTEGER NOT NULL REFERENCES purchase_orders(id),
  sku         TEXT, description TEXT,
  qty         REAL NOT NULL DEFAULT 1,
  unit_cost   REAL NOT NULL
);

CREATE TABLE client_devices (                     -- THEIR hardware (≠ our assets)
  id              INTEGER PRIMARY KEY,
  project_id      INTEGER NOT NULL REFERENCES projects(id),
  client_id       INTEGER NOT NULL REFERENCES clients(id),
  serial_no       TEXT,
  kind            TEXT NOT NULL DEFAULT 'sensor', -- gateway|sensor|camera
  firmware_version TEXT, site_location TEXT,      -- "Pump station 2"
  warranty_until  TEXT,
  status          TEXT NOT NULL DEFAULT 'ordered' -- ordered|shipped|installed|faulty|rma
);

-- ── INVESTORS & FUNDING ────────────────────────────────────────────────────
CREATE TABLE investors (
  id      INTEGER PRIMARY KEY,
  name    TEXT NOT NULL,
  contact TEXT, iban TEXT, notes TEXT
);

CREATE TABLE project_funding (
  id              INTEGER PRIMARY KEY,
  project_id      INTEGER NOT NULL REFERENCES projects(id),
  target_amount   REAL NOT NULL,
  status          TEXT NOT NULL DEFAULT 'seeking',
                  -- seeking|committed|funded|returned|closed
  source_kind     TEXT NOT NULL DEFAULT 'fresh', -- fresh|salvage_round
  salvage_of_project_id INTEGER,            -- round that salvages a defaulted project
  terms_summary   TEXT, agreement_url TEXT,
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE investments (
  id               INTEGER PRIMARY KEY,
  funding_id       INTEGER NOT NULL REFERENCES project_funding(id),
  investor_id      INTEGER NOT NULL REFERENCES investors(id),
  amount           REAL NOT NULL,                -- 10000
  promised_return  REAL NOT NULL,                -- 15000 (snapshot)
  return_rule      TEXT NOT NULL DEFAULT 'fixed',-- fixed|multiple|revenue_share
  invested_at      TEXT NOT NULL DEFAULT (datetime('now')),
  funds_received_at TEXT
);

CREATE TABLE investor_payouts (                   -- same guard as team payouts
  id                 INTEGER PRIMARY KEY,
  investment_id      INTEGER NOT NULL REFERENCES investments(id),
  amount             REAL NOT NULL,
  status             TEXT NOT NULL DEFAULT 'accrued',
                     -- accrued|blocked|payable|paid
  trigger_payment_id INTEGER REFERENCES payments(id),  -- client 50k payment
  payable_at         TEXT, paid_at TEXT, paid_via TEXT
);

CREATE TABLE funding_waterfalls (                 -- distribution recipe
  funding_id INTEGER NOT NULL REFERENCES project_funding(id),
  order_no   INTEGER NOT NULL,
  target     TEXT NOT NULL,                       -- investors|agency
  pct        REAL, cap REAL,
  PRIMARY KEY (funding_id, order_no)
);

-- ── MODULE ADD-ONS (AI-assisted builds, flat fees) ─────────────────────────
CREATE TABLE module_orders (
  id              INTEGER PRIMARY KEY,
  client_id       INTEGER NOT NULL REFERENCES clients(id),
  project_id      INTEGER NOT NULL REFERENCES projects(id),
  ticket_id       INTEGER REFERENCES tickets(id),
  proposal_id     INTEGER REFERENCES proposals(id),
  name            TEXT NOT NULL,                  -- "HR Module"
  scope           TEXT,
  price           REAL NOT NULL DEFAULT 0,        -- client pays 3000
  team_member_id  INTEGER REFERENCES team_members(id),
  team_fee        REAL NOT NULL DEFAULT 0,        -- FLAT 500 (overrides comp_plans)
  ai_tool         TEXT,                           -- opencode | claude_code
  status          TEXT NOT NULL DEFAULT 'requested',
                  -- requested|quoted|accepted|building|in_review|deployed|invoiced|cancelled
  branch          TEXT,                           -- module/hr
  pr_number       INTEGER,
  build_spec      TEXT,                           -- generated prompt (stack+brand+scope)
  started_at      TEXT, deployed_at TEXT,
  invoice_id      INTEGER REFERENCES invoices(id)
);

ALTER TABLE payouts ADD COLUMN module_order_id INTEGER REFERENCES module_orders(id);

-- ════════════════════════════════════════════════════════════════════
-- V3 (docs 15, 16, 17) — INTEGRATIONS & CREDENTIALS
-- Philosophy: client owns accounts & cards; agency holds encrypted,
-- scoped, revocable access only. Card numbers are NEVER stored (PCI).
-- ════════════════════════════════════════════════════════════════════

-- Only place secrets live. AES-256-GCM ciphertext; key comes from env.
CREATE TABLE credentials (
  id             INTEGER PRIMARY KEY,
  client_id      INTEGER NOT NULL REFERENCES clients(id),
  project_id     INTEGER REFERENCES projects(id),
  provider       TEXT NOT NULL,     -- google|airtable|formaloo|meta|vercel|tap|moyasar|ssh|other
  kind           TEXT NOT NULL,     -- oauth_token|api_key|ssh_key|service_account
  ciphertext     TEXT NOT NULL,     -- AES-256-GCM
  iv             TEXT NOT NULL,
  auth_tag       TEXT NOT NULL,
  scopes         TEXT,              -- least-privilege scope string
  expires_at     TEXT,
  last_rotated   TEXT,
  status         TEXT NOT NULL DEFAULT 'active',  -- active|revoked
  last_used_at   TEXT
);

-- Every secret READ is logged (actor, action, entity, entity_id, at).
CREATE TABLE audit_log (
  id        INTEGER PRIMARY KEY,
  actor     TEXT NOT NULL,         -- team member or system job
  action    TEXT NOT NULL,         -- read|create|rotate|revoke|use
  entity    TEXT NOT NULL,         -- credential|repo|target|invoice|...
  entity_id INTEGER,
  at        TEXT NOT NULL DEFAULT (datetime('now'))
);

-- The connector layer the client never sees the internals of.
CREATE TABLE connector_catalog (
  provider        TEXT PRIMARY KEY,  -- airtable|formaloo|whatsapp|google|hostinger|...
  category        TEXT NOT NULL,     -- tables|forms|messaging|auth|hosting
  auth_type       TEXT NOT NULL,     -- oauth|api_key|ssh
  pricing_model   TEXT,              -- free|per_seat|usage — for advisory cards
  owned_by        TEXT NOT NULL DEFAULT 'client',  -- client|agency — never mix in margin reports
  selection_notes TEXT               -- plain-language "when to pick this"
);

CREATE TABLE project_connectors (
  id                  INTEGER PRIMARY KEY,
  client_id           INTEGER NOT NULL REFERENCES clients(id),
  project_id          INTEGER REFERENCES projects(id),
  credential_id       INTEGER REFERENCES credentials(id),
  status              TEXT NOT NULL DEFAULT 'requested', -- requested|provisioned|connected|broken
  provisioned_at      TEXT,
  external_ref        TEXT,           -- provider-side record id (never secrets)
  last_healthcheck_at TEXT            -- cron: token valid? quota ok? broken -> auto-ticket
);

-- LANE B — client's own recurring third-party costs: TRACKED, NEVER BILLED.
CREATE TABLE external_client_costs (
  id                     INTEGER PRIMARY KEY,
  client_id              INTEGER NOT NULL REFERENCES clients(id),
  project_id             INTEGER REFERENCES projects(id),
  provider               TEXT NOT NULL,
  plan                   TEXT,
  amount                 INTEGER NOT NULL,  -- minor units, advisory only
  currency               TEXT NOT NULL DEFAULT 'USD',
  billing_day            INTEGER,
  status                 TEXT NOT NULL DEFAULT 'active',  -- active|downgraded|cancelled
  renewal_notice_sent_at TEXT             -- cron reminds CLIENT, not your card
);

-- repo_policy: agency code is yours until paid; data/accounts always theirs.
ALTER TABLE client_repos ADD COLUMN repo_policy TEXT DEFAULT 'agency_held'; -- agency_held|shared|transferred

-- ════════════════════════════════════════════════════════════════════
-- V3 — DEPLOYMENT TARGETS (doc 16) — four adapters, one pipeline
-- ════════════════════════════════════════════════════════════════════

CREATE TABLE deployment_targets (
  id             INTEGER PRIMARY KEY,
  client_repo_id INTEGER NOT NULL REFERENCES client_repos(id),
  env            TEXT NOT NULL,      -- staging|production
  provider       TEXT NOT NULL,      -- vercel|hostinger_vps|generic_paas|office_vps
  domain         TEXT,
  credential_id  INTEGER REFERENCES credentials(id),  -- API token / SSH key from vault
  env_vars_json  TEXT,               -- NAMES only; values live in vault
  deploy_method  TEXT NOT NULL,      -- api|ssh_script|agent_poll
  status         TEXT NOT NULL DEFAULT 'never_deployed', -- never_deployed|healthy|degraded|pending_agent
  last_deploy_at TEXT,
  current_sha    TEXT,
  health_url     TEXT
);
-- Adapter contract: deploy(sha) / rollback() / healthcheck() / logs().
-- office_vps = pull-agent model (no inbound firewall holes).
-- Payment gate: all production targets healthy + client acceptance click
--   -> invoice (snapshot price) + hardware POs -> payment webhook -> maintenance.

-- ════════════════════════════════════════════════════════════════════
-- V3 — SERVICE-SCHEMA REUSE (doc 17)
-- The attribute/variant/quote engine lives in zainpreneur-app's catalogue
-- (AttributeRecord / AttributeValue / Variant / Quote / RequestSnapshot /
-- LeadProposal). Only the integration rule for THIS plan's tables:
--
--   client-chosen AND price-affecting -> attribute/value
--   event or money movement            -> plain typed column
--   NEVER the reverse.
--
-- proposal_lines are GENERATED by the Quote engine (basePrice +
-- variantExtra + attributeExtras + configurationCharges +
-- additionalServices - discount) and frozen into proposals.snapshot at
-- acceptance; estimatedCost stays off the client PDF.
-- Ledger tables above stay attribute-free by design.
-- ════════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════════
-- V4 (doc 18) — SOLO MODE: owner is the only app user
-- Portals are never built; every stakeholder touchpoint is a generated
-- message (WhatsApp/email) + a status column the owner flips.
-- Portals, if ever wanted, are pure read-views over these same tables.
-- ════════════════════════════════════════════════════════════════════

CREATE TABLE message_templates (
  code           TEXT PRIMARY KEY,   -- invoice_send, proposal_send, live_notice, payout_digest, investor_monthly
  channel        TEXT NOT NULL,      -- whatsapp|email
  title          TEXT NOT NULL,
  body           TEXT NOT NULL,      -- merge fields: {client} {amount} {link} {due} ...
  variables_json TEXT,               -- declared variables for render-time checks
  active         TEXT NOT NULL DEFAULT 'yes'
);

-- The OS remembers what was said, out-of-band, per stakeholder.
CREATE TABLE comms_log (
  id                INTEGER PRIMARY KEY,
  contactable_type  TEXT NOT NULL,   -- lead|client|investor|team|vendor
  contactable_id    INTEGER NOT NULL,
  channel           TEXT NOT NULL,   -- whatsapp|email|call
  direction         TEXT NOT NULL,   -- out|in
  template_code     TEXT REFERENCES message_templates(code),
  snippet           TEXT NOT NULL,   -- rendered message or pasted reply (verbatim)
  at                TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Solo-mode payment/acceptance recording (human confirms out-of-band).
ALTER TABLE invoices ADD COLUMN payment_confirmation TEXT;        -- webhook|manual
ALTER TABLE proposals ADD COLUMN acceptance_channel TEXT;        -- whatsapp|email|verbal
ALTER TABLE proposals ADD COLUMN acceptance_note TEXT;           -- pasted reply snippet
-- Daily queue is a computed view, not a table: follow-ups due +
-- invoices ready + unpaid > 7 days + payout digests due today.

-- ════════════════════════════════════════════════════════════════════
-- V4b (doc 19) — PROCUREMENT PO gaps found by the POS walkthrough
-- ════════════════════════════════════════════════════════════════════

-- Which pot pays: investor-advance (restricted, doc 13) vs own cash.
ALTER TABLE purchase_orders ADD COLUMN funding_id INTEGER REFERENCES project_funding(id);
-- Who executes the purchase (owner or an assigned team member).
ALTER TABLE purchase_orders ADD COLUMN assigned_team_member_id INTEGER REFERENCES team_members(id);
-- Proof of purchase (receipt photo/file) — gate for marking received.
ALTER TABLE purchase_orders ADD COLUMN receipt_url TEXT;

-- Investor seniority pattern (doc 19): book principal and upside as
-- SEPARATE investor_payouts rows on the same investment — tiers 1/3 in
-- the walkthrough — so a partial client payment clears principal +
-- team fee before any profit leg.
-- Message template codes used by the flows: proposal_send, invoice_send,
-- live_notice, pos_procurement_instruction, payout_digest, investor_monthly.

-- ════════════════════════════════════════════════════════════════════
-- V5 (doc 20) — LOSS & DEFAULT WATERFALL (the mirror image)
-- Defaulted project: freeze -> liquidate -> distribute pro-rata to
-- investor CAPITAL first -> upside cancelled -> agency absorbs the rest.
-- Realized loss per investor = investments.amount - SUM(recovery_distributions).
-- ════════════════════════════════════════════════════════════════════

-- projects.status  gains 'defaulted' (then 'written_off' after distribution)
-- invoices.status  gains 'uncollectible' (never paid; 30k is not revenue)
-- investor_payouts.status gains 'cancelled' (upside dies with the revenue)

-- Procurement gate: POs funded by investor advance require a recorded
-- client deposit, or an audited waiver note.
ALTER TABLE purchase_orders ADD COLUMN deposit_gate_waiver TEXT;

CREATE TABLE asset_dispositions (              -- liquidation of project assets
  id         INTEGER PRIMARY KEY,
  project_id INTEGER NOT NULL REFERENCES projects(id),
  po_id      INTEGER REFERENCES purchase_orders(id),
  kind       TEXT NOT NULL,                    -- server|license|device
  disposition TEXT NOT NULL,                   -- returned|resold|repurposed
  proceeds   REAL NOT NULL,                    -- cash actually recovered
  fee        REAL NOT NULL DEFAULT 0,          -- restocking/shipping
  counterparty TEXT,
  at         TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE recovery_distributions (          -- who gets salvaged cash, in order
  id            INTEGER PRIMARY KEY,
  investment_id INTEGER NOT NULL REFERENCES investments(id),
  source        TEXT NOT NULL,                 -- unspent_pot|liquidation|repurposed_sale|agency_goodwill
  amount        REAL NOT NULL,                 -- pro-rata to capital in
  at            TEXT NOT NULL DEFAULT (datetime('now'))
);
-- Prevention gates (doc 20): deposit-before-procure, milestone buying,
-- concentration cap, margin sanity, guaranteed-return-is-debt (a fixed
-- return NOT tied to client payment is recorded as a LOAN, never as
-- investments), client-vanish nag list while assets are still returnable.

-- ════════════════════════════════════════════════════════════════════
-- V6 (doc 21) — THE SALVAGE PLAY (dead deal -> next deal -> everyone whole)
-- Schema cost of the whole seam: the two columns above
-- (project_funding.source_kind/salvage_of_project_id) and the
-- repurposed_sale source code. Everything else reuses existing rows:
--   - dead deal's code -> templates row (internal template is born)
--   - servers -> asset_dispositions (repurposed at book value)
--   - new funding round tagged salvage_round, offered first to the
--     prior investors with enhanced (still trigger-bound) terms
--   - team: cancelled old fee honored as flat delivery + bonus rows on
--     the new deal — the guard is never broken, the work rides a deal
--     that has cash
-- Net example: 60k waterfall -> recovery 9k, team 12k, investors 30k,
-- agency margin 9k + template IP + 49 warmed leads.
-- ════════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════════
-- V7 (doc 22) — EMAIL-FIRST COMMUNICATIONS (WhatsApp deferred)
-- ~45 plain-text templates across 6 stakeholders, each with stage,
-- trigger, expected reply -> status flip, and sequence chaining.
-- ════════════════════════════════════════════════════════════════════

ALTER TABLE message_templates ADD COLUMN stakeholder TEXT;  -- lead|client|investor|team|vendor|any
ALTER TABLE message_templates ADD COLUMN stage TEXT;        -- pipeline stage it belongs to
ALTER TABLE message_templates ADD COLUMN trigger_note TEXT; -- when the owner sends this
ALTER TABLE message_templates ADD COLUMN expected_reply TEXT; -- what a reply means (status flip)
ALTER TABLE message_templates ADD COLUMN followup_template_code TEXT REFERENCES message_templates(code);
ALTER TABLE message_templates ADD COLUMN followup_after_days INTEGER;

-- The daily worklist, made real. Sending a template auto-schedules its
-- followup row; any inbound reply cancels pending rows (cancelled_by).
CREATE TABLE outbox (
  id                INTEGER PRIMARY KEY,
  contactable_type  TEXT NOT NULL,    -- lead|client|investor|team|vendor
  contactable_id    INTEGER NOT NULL,
  template_code     TEXT NOT NULL REFERENCES message_templates(code),
  subject           TEXT,             -- rendered, owner-editable
  body              TEXT,             -- merge fields resolved, owner-editable
  due_at            TEXT NOT NULL,
  status            TEXT NOT NULL DEFAULT 'scheduled', -- scheduled|ready|sent|skipped
  sent_at           TEXT,
  comms_log_id      INTEGER REFERENCES comms_log(id),
  cancelled_by      TEXT              -- inbound_reply|status_change|manual
);
-- Template catalogue (doc 22): L1-L10 leads, C1-C12 clients/delivery,
-- P1-P7 invoicing, V1-V8 vendors, I1-I11 investors, T1-T9 team.
-- Sequences are CHAINS OF ROWS (followup_template_code + days), not an
-- automation engine: ColdLead L1>L2>L3>L4 · Proposal L7>L8>L9 ·
-- Delivery C1..C11 · Invoice P1>P2>P3>P4 · Vendor V2..V6 ·
-- Investor I2..I8 · Team T2..T7.
-- v1 send = copy-to-clipboard + mailto (subject pre-filled); WhatsApp
-- and send APIs deferred — channel column is ready when they arrive.
