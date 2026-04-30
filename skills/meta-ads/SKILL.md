---
name: meta-ads
description: "Meta Ads management and reporting — daily checks, campaign performance, creative fatigue, bleeders, winners. Uses the installed meta-ads CLI for Facebook/Instagram ads. The '5 Daily Questions' that replace Ads Manager."
version: 1.0.0
author: Matt Berman
license: MIT
prerequisites:
  commands:
    - meta-ads
    - jq
metadata:
  hermes:
    category: marketing
    tags:
      - meta-ads
      - facebook-ads
      - instagram-ads
      - reporting
      - performance-marketing
    related_skills:
      - ad-creative-monitor
      - budget-optimizer
      - ad-copy-generator
      - ad-upload
      - pixel-capi
    requires_toolsets:
      - terminal
---

# Meta Ads — Your AI Ad Manager

Stop clicking through Ads Manager. This skill uses the installed `meta-ads` CLI to give you the five things that actually matter about your Meta campaigns — in plain text, every day.

The thesis: 90% of ad management is pattern recognition. Spend trending up or down. CTR declining (creative fatigue). CPA spiking (audience exhaustion). Winners emerging. Losers bleeding.

This skill spots the patterns. You make the calls.

Read `workspace/brand/` when available for account context, brand goals, and prior learnings.

Follow the output formatting and safety rules in this skill.

---

## Brand Memory Integration

**Reads:** `stack.md`, `creative-kit.md`, `audience.md`, `learnings.md` (all optional)

| File | What it provides | How it shapes output |
|------|-----------------|---------------------|
| `workspace/brand/stack.md` | Stored ad account ID, target CPA/ROAS | Auto-fills account, benchmarks performance against targets |
| `workspace/brand/creative-kit.md` | Brand creative guidelines, assets | Context for creative recommendations |
| `workspace/brand/audience.md` | Target audience profiles | Interprets audience performance data |
| `workspace/brand/learnings.md` | Past performance patterns | Spots recurring issues — "this happened last month too" |

### Writes

| File | What it contains |
|------|-----------------|
| `workspace/brand/stack.md` | Stores ad account ID on first use |
| `workspace/brand/learnings.md` | Appends performance findings, fatigue patterns, winning creative traits |

---

## Setup (One Time)

### 1. Install/configure `meta-ads`

```bash
meta-ads auth status
```

If needed, set `META_ADS_CLI=/absolute/path/to/meta-ads`. The CLI loads `ACCESS_TOKEN`, `AD_ACCOUNT_ID`, and optional `BUSINESS_ID` from your environment or `~/.hermes/envs/meta-ads/.env`. Store secrets safely, for example in 1Password, and never commit them.

### 2. Create a Meta App (if you don't have one)

1. Go to [developers.facebook.com](https://developers.facebook.com) → My Apps → Create App
2. Choose "Business" type
3. Add "Marketing API" product
4. Note your App ID and App Secret

### 3. Configure credentials

Set `ACCESS_TOKEN` with `ads_read` and `read_insights` for reporting. Add `ads_management` only for approved interactive actions.

```bash
export ACCESS_TOKEN=EAAB...
meta-ads auth status
```

### 4. Set default ad account

```bash
meta-ads -o json ads adaccount list
```

Set env: `export AD_ACCOUNT_ID=act_123456`

---

## Reports

### The 5 Daily Questions ← Start Here

The core of the system. Five questions that replace 20 minutes of Ads Manager clicking:

1. **Am I on track?** — Today's spend vs expectations
2. **What's running?** — Active campaigns at a glance
3. **How's performance?** — 7-day metrics by campaign
4. **Who's winning/losing?** — Ad-level performance sorted
5. **Any fatigue?** — CTR trends, frequency, CPC movement

```
Tell me: "Daily ads check"
Or: "Run the 5 questions on my ads"
Or: "How are my Meta ads doing?"
```

Script (installed skill): `bash "${HERMES_SKILL_DIR}/scripts/meta-ads.sh" daily-check`

### Overview

Account-level summary with campaign breakdown.

```
Tell me: "Meta ads overview for last 30 days"
```

Script (installed skill): `bash "${HERMES_SKILL_DIR}/scripts/meta-ads.sh" overview --date-preset last_30d`

### Campaigns

List campaigns, optionally filtered by status.

```
Tell me: "Show me active campaigns"
```

Script (installed skill): `bash "${HERMES_SKILL_DIR}/scripts/meta-ads.sh" campaigns --status ACTIVE`

### Top Creatives

Ad-level performance ranked by results.

```
Tell me: "What are my best performing ads?"
```

Script (installed skill): `bash "${HERMES_SKILL_DIR}/scripts/meta-ads.sh" top-creatives --date-preset last_7d`

### Bleeders 🩸

Ads with high spend but poor performance — candidates for pause. Flags ads with CTR < 1% or frequency > 3.5.

```
Tell me: "Any ads bleeding money?"
Or: "Find underperforming ads"
```

Script (installed skill): `bash "${HERMES_SKILL_DIR}/scripts/meta-ads.sh" bleeders --date-preset last_7d`

### Winners 🏆

Top performing ads by CTR and efficiency. These are your scale candidates.

```
Tell me: "Which ads should I scale?"
Or: "Show me the winners"
```

Script (installed skill): `bash "${HERMES_SKILL_DIR}/scripts/meta-ads.sh" winners --date-preset last_7d`

### Fatigue Check 😴

Daily breakdown to spot creative fatigue — CTR declining day-over-day, frequency climbing, CPC rising.

```
Tell me: "Any creative fatigue?"
Or: "Check for ad fatigue"
```

Script (installed skill): `bash "${HERMES_SKILL_DIR}/scripts/meta-ads.sh" fatigue-check`

### Custom

Full control. Specify fields, repeated breakdowns, date ranges, and optional `--campaign-id`, `--adset-id`, or `--ad-id` filters.

```
Tell me: "Show me ad performance broken down by age and gender"
```

Script (installed skill): `bash "${HERMES_SKILL_DIR}/scripts/meta-ads.sh" custom --fields "ad_name,ad_id,spend,ctr,cpc" --breakdown age --breakdown gender`

---

## Date Presets

- `today` — Today only
- `yesterday` — Yesterday only
- `last_7d` — Last 7 days (default for most reports)
- `last_30d` — Last 30 days
- `last_90d` — Last 90 days

---

## Actions (Use With Care)

Beyond reporting, `meta-ads` can take action. These are for the "AI ad manager" workflow but require explicit approval.

### Pause a bleeder
```bash
meta-ads ads ad pause AD_ID
```

### Resume a winner
```bash
meta-ads ads ad resume AD_ID
```

### Shift budget
```bash
meta-ads ads adset budget set ADSET_ID --daily-budget 5000  # in cents
```

**Safety:** All mutating actions are high-risk and require confirmation. The skill should ALWAYS present findings and recommendations first, then ask for explicit approval before taking action.

---

## The AI Ad Manager Workflow

This is the system from the newsletter. Here's how it works in practice:

**Morning (automated via Hermes cron, read-only):**
1. Run `daily-check`
2. Flag bleeders (CTR < 1%, frequency > 3.5, CPA > threshold)
3. Flag winners (top CTR, low CPC, scaling headroom)
4. Send summary to Telegram/Slack
5. Do not pause ads, change budgets, upload creatives, or take any spend-affecting action from cron

**You (2 minutes over coffee):**
1. Read the summary
2. Approve/reject recommendations
3. Ask follow-up questions if needed

**The AI (on approval):**
1. Pause confirmed bleeders
2. Increase budget on confirmed winners
3. Log decisions to learnings.md

---

## Invocation

When the user asks about Meta ads, Facebook ads, Instagram ads, or campaign performance:

1. Check `workspace/brand/stack.md` for stored ad account ID
2. Check `AD_ACCOUNT_ID` env var
3. If neither, run `meta-ads -o json ads adaccount list` to list available accounts
4. Run the appropriate report
5. Interpret results in context of brand goals (from stack.md/learnings.md)
6. For bleeders/winners, present clear recommendations with reasoning
7. **Never take action without explicit user approval**
8. Log findings to `workspace/brand/learnings.md`

### The 5 Daily Questions (Detailed)

When running daily-check, frame the output around these questions:

1. **"Am I on track?"** — Compare today's spend rate to daily budget. If pacing high or low, flag it.
2. **"What's running?"** — List active campaigns with status. Flag any that should be off.
3. **"How's the last 7 days?"** — Campaign-level metrics. Compare to previous 7 if available.
4. **"Who's winning and who's losing?"** — Ad-level sort. Top 3 winners, bottom 3 losers with specific metrics.
5. **"Any fatigue signals?"** — Frequency trends, CTR day-over-day, CPC movement. Concrete numbers, not vibes.

---

## Next Up

Optional adjacent capabilities if you have them installed:

- **GA4 reporting** — See what Meta traffic actually does on your site. Pair with ads data to find true ROAS.
- **GSC reporting** — Cross-reference paid vs organic. Are you paying for traffic you'd get free?
- **Creative generation** — Generate new ad creatives when fatigue hits. Feed winning patterns into new concepts.
- **Direct-response copywriting** — Write ad copy based on what's actually converting.
