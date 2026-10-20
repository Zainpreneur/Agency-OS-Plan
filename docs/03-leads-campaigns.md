# 03 — Leads & Marketing Campaigns

From 1-to-1 selling to 1-to-many demand generation: the schema shift is
**Campaign × Lead attribution** as a first-class relationship, plus a
pacing-aware outreach queue.

## Tables

```sql
leads              -- discovery record: source, has_website, status, next_follow_up_at
lead_activities    -- append-only timeline (note|call|whatsapp|email|demo_opened|…)
campaigns          -- the effort: kind, budget, spend, message_variant, status
campaign_targets   -- campaign × lead × step; rendered message_body stored
sequence_steps     -- Day 0/3/7/14 templates, channel, stop_on_reply behavior
```

`leads` also carries **attribution columns**: `first_campaign_id`,
`first_touch_at`, `converting_campaign_id`, `touch_count`.

## Lead statuses

`discovered → contacted → demo_built → demo_shared → proposal_sent →
negotiating → won / lost / archived`

`next_follow_up_at` is the field that makes a CRM actually work.

## Campaign workflow (the 200 furniture leads)

1. **Import** — Google Maps scraper / CSV; dedupe on phone + business_name
   (the same shop twice = spam).
2. **Filter** — `industry=furniture AND has_website=false` → 200 targets.
3. **Sequence** (example):
   - Day 0 · WhatsApp · "Hi {{business_name}} — saw you don't have a website,
     we built a demo for furniture stores, want it?" + short link
   - Day 3 · WhatsApp · "Demo expires Friday — want me to send it?"
   - Day 7 · Call · a **task for you**, not an auto-send
   - Day 14 · Email · "Last note — 20% off if we build this month"
4. **Pacing** — a cron sends ~25/day from `campaign_targets WHERE
   status='scheduled'`; never blast 200 in an hour (blocks + spam reports).
5. **Replies stop sequences** — `stop_on_reply` skips remaining steps the
   moment a human answers. Auto-chasing past a reply destroys trust.
6. Every send writes `lead_activities` with `campaign_id` → the list becomes
   a live funnel.

## The funnel dashboard

```
Campaign                 Targets Sent Opened Replied Demos Won  Spend  Cost/win
Furniture-Oct (WA seq)   200    178  121    34      19    7    800    114
Furniture-Referral        40     40   31     12      9     4      0      0
```

Metrics for free: cost per reply, cost per win, revenue per campaign, A/B
variant win rates, days-to-close, **discount % by channel** (WhatsApp leads
accept 3k, ad leads demand 2.5k — next quarter's budget decision).

## Attribution rules

- **First touch** = which channel *found* the market
- **Last touch** (`converting_campaign_id`, copied onto the sale at win) =
  which channel *closed* it
- Store the **rendered** `message_body` on every target — "what exactly did
  we promise whom" is a legal + sanity issue at hundreds of touches
- Failures (`status='failed'`: bad number, blocked) are data — they clean
  the list, never silently dropped

## Lost leads are pipeline

`lost_reason` = price / no_response / diying / bad_fit → "no" re-opens as a
warm re-proposal in 6 months (or a maintenance-only offer).
