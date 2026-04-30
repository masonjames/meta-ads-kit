# Meta Ads Copilot — Full Spec

**Created:** Feb 23, 2026
**Status:** v1.0 — Ready to ship
**Owner:** @themattberman

---

## Overview

A Hermes-compatible Meta Ads manager that replaces daily Ads Manager sessions with AI-generated briefings and recommendations.

**The Promise:**
Authenticate your ad account → Get daily briefings with bleeders, winners, fatigue alerts, and tracking-health signals → Approve actions from your phone in an interactive session

**Target Users:**
- Founders running their own Meta ads
- Small marketing teams without a dedicated media buyer
- Agency operators managing multiple accounts
- Anyone tired of clicking through Ads Manager

---

## System Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                       META ADS COPILOT                         │
│                       (Hermes Agent)                           │
│                                                                │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐           │
│  │  meta-ads    │ │  creative    │ │  budget      │           │
│  │  (core)      │ │  monitor     │ │  optimizer   │           │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘           │
│         │                │                │                   │
│  ┌──────▼───────┐ ┌──────▼───────┐ ┌──────▼───────┐           │
│  │ ad-copy-gen  │ │  ad-upload   │ │  pixel-capi  │           │
│  │              │ │              │ │              │           │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘           │
│         │                │                │                   │
│         └────────┬───────┴────────┬───────┘                   │
│                  ▼                ▼                           │
│        ┌────────────────┐ ┌──────────────────────┐            │
│        │   social-cli   │ │  Graph API scripts   │            │
│        │  (reporting)   │ │ uploads + Pixel/CAPI │            │
│        └───────┬────────┘ └──────────┬───────────┘            │
│                ▼                     ▼                        │
│        ┌──────────────────────────────────────────┐            │
│        │          Meta Marketing API              │            │
│        │       Facebook / Instagram Ads           │            │
│        └──────────────────────────────────────────┘            │
│                                                                │
│  Hermes cron may schedule read-only briefings with installed   │
│  skills and this repo as --workdir. Mutations are interactive. │
└────────────────────────────────────────────────────────────────┘
```

---

## The 6 Skills

### Skill 1: `meta-ads` (Core)
**Purpose:** Daily reporting and ad management actions

**Reports:**
- Daily check (5 Daily Questions)
- Account overview
- Campaign listing
- Top creatives
- Bleeders (high spend, low performance)
- Winners (top performers)
- Fatigue check
- Custom reports with breakdowns

**Actions (require approval):**
- Pause ad/adset/campaign
- Resume ad/adset/campaign
- Adjust budget

### Skill 2: `ad-creative-monitor`
**Purpose:** Track creative health over time

**Capabilities:**
- Day-over-day CTR tracking
- Frequency creep detection
- CPC inflation alerts
- Creative lifespan estimation
- Rotation recommendations

### Skill 3: `budget-optimizer`
**Purpose:** Spend efficiency analysis

**Capabilities:**
- Campaign efficiency ranking
- Budget shift recommendations
- Spend pacing checks
- ROI comparison across campaigns

### Skill 4: `ad-copy-generator`
**Purpose:** Generate ad copy matched to specific image creatives

**Capabilities:**
- Analyze image creative (visual style, on-image text, concept, angle)
- Cross-reference account performance data for winning copy patterns
- Generate 3-5 headline variants (25-40 chars) + 3-5 body variants (50-120 words)
- Output in `asset_feed_spec` format for Meta's Degrees of Freedom optimization
- Apply brand voice from `workspace/brand/voice-profile.md`
- Include psychology-driven hooks (social proof, fear of loss, status, etc.)

### Skill 5: `ad-upload`
**Purpose:** Push ads to Meta via Graph API without Ads Manager

**Capabilities:**
- Upload images to Meta ad account (returns image hashes)
- Build `asset_feed_spec` creatives with multiple copy variants
- Create ads in existing ad sets
- Support all Meta placement sizes (Feed, Stories, Reels)
- Link page and Instagram account for cross-placement delivery

**Actions (require approval):**
- Uploading images to an ad account
- Creating creatives or ads
- Launching, pausing, or changing ad status

### Skill 6: `pixel-capi`
**Purpose:** Audit Meta Pixel + Conversions API setup and improve tracking quality

**Capabilities:**
- Audit Pixel installation and Conversions API health
- Test server-side events and deduplication
- Check Event Match Quality and recommend improvements
- Provide platform-specific guidance for common website stacks
- Help validate tracking before campaign optimization decisions

**Actions (require approval):**
- Sending production CAPI events
- Changing tracking configuration
- Any attribution-affecting update

---

## Data Flow

### Morning Briefing (Hermes Cron, Read-Only)
1. Hermes cron triggers a scheduled prompt with installed skills and this repo as `--workdir`
2. Agent pulls insights via social-cli and/or read-only scripts
3. Analyzes: spend pacing, active campaigns, 7-day trends
4. Identifies: bleeders, winners, fatigue signals, budget recommendations, and optional tracking risks
5. Generates: summary with recommendations
6. Delivers: to configured channel (Telegram/Slack/etc)
7. Does not take action: cron runs are headless and cannot collect approval

Recommended cron skill set for the daily briefing:

```bash
--skills "meta-ads,ad-creative-monitor,budget-optimizer"
```

Optional tracking-health jobs can use:

```bash
--skills "pixel-capi"
```

Cron jobs must report and recommend only. Pauses, budget edits, uploads, production CAPI sends, and tracking changes are interactive-only.

### On-Demand (Interactive)
1. User asks a question ("how are my ads?")
2. Agent determines which report(s) or skill(s) to run
3. Pulls data via appropriate script
4. Interprets in context of benchmarks (`ad-config.json`)
5. Presents findings with actionable recommendations
6. If action needed: asks for explicit approval
7. After approval: executes the action and logs the outcome

---

## Configuration

Runtime configuration comes from social-cli authentication, `.env`, and `ad-config.json`.

| Variable | Purpose |
|----------|---------|
| `META_AD_ACCOUNT` | Default Meta ad account, e.g. `act_123456789`; optional if social-cli has a default account |
| `FACEBOOK_ACCESS_TOKEN` | Graph API token for upload workflows and account-performance lookup workflows |
| `META_TOKEN` | Graph API token for Pixel/CAPI scripts; some scripts can fall back to social-cli config when supported |

---

## Benchmarks & Thresholds

Default thresholds (configurable in `ad-config.json`):

| Metric | Default | Purpose |
|--------|---------|---------|
| Bleeder CTR | < 1.0% | Flag underperforming ads |
| Max frequency | > 3.5 | Creative seeing fatigue |
| Fatigue CTR drop | > 20% over 3 days | Early fatigue warning |
| Spend pace alert | ±15% of daily budget | Over/underspend warning |
| Target CPA | $25.00 | Campaign efficiency target |
| Target ROAS | 3.0x | Return on ad spend target |

---

## Safety Model

### Read-Only by Default
All reporting is read-only. The agent can pull any data without asking.

### Hermes Cron Is Read-Only
Hermes cron may run scheduled briefings, audits, and recommendation jobs. Cron jobs must not pause ads, resume ads, change budgets, upload creatives, create ads, send production CAPI events, or change tracking configuration because cron is headless and cannot collect approval.

### Actions Require Approval
Any action that affects spend or attribution requires explicit user confirmation:
- Pausing/resuming ads
- Budget changes
- Status changes
- Ad uploads or ad creation
- Production CAPI sends
- Tracking configuration changes

### Audit Trail
Every action is logged to `workspace/brand/learnings.md` with:
- Timestamp
- What was changed
- Why (data justification)
- Who approved (user confirmation)

---

## Future Roadmap

- [ ] Google Ads support (when social-cli adds it)
- [ ] Multi-account dashboard for agencies
- [ ] Automated A/B test detection and analysis
- [ ] Creative performance prediction
- [ ] Automated reporting (weekly PDF/email)
- [ ] Competitor ad monitoring integration
- [ ] Slack/Discord native notifications
