# Meta Ads Copilot — Full Spec

**Created:** Feb 23, 2026
**Status:** v1.0 — Ready to ship
**Owner:** @themattberman

---

## Overview

An OpenClaw-powered Meta Ads manager that replaces daily Ads Manager sessions with AI-generated briefings and recommendations.

**The Promise:**
Authenticate your ad account → Get daily briefings with bleeders, winners, and fatigue alerts → Approve actions from your phone

**Target Users:**
- Founders running their own Meta ads
- Small marketing teams without a dedicated media buyer
- Agency operators managing multiple accounts
- Anyone tired of clicking through Ads Manager

---

## System Architecture

```
┌──────────────────────────────────────────────────────┐
│                META ADS COPILOT                       │
│                                                       │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ │
│  │  meta-ads    │  │  creative    │  │  budget    │ │
│  │  (core)      │  │  monitor     │  │  optimizer │ │
│  └──────┬───────┘  └──────┬───────┘  └─────┬──────┘ │
│         │                 │                 │        │
│         └────────────┬────┴─────────────────┘        │
│                      ▼                                │
│         ┌─────────────────────────┐                  │
│         │      social-cli         │                  │
│         │  (Meta Marketing API)   │                  │
│         └───────────┬─────────────┘                  │
│                     ▼                                 │
│         ┌─────────────────────────┐                  │
│         │   Meta Marketing API    │                  │
│         │  (Facebook/Instagram)   │                  │
│         └─────────────────────────┘                  │
└──────────────────────────────────────────────────────┘
```

---

## The 3 Skills

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

---

## Data Flow

### Morning Briefing (Automated)
1. Cron triggers daily check at configured time
2. Agent pulls insights via social-cli
3. Analyzes: spend pacing, active campaigns, 7-day trends
4. Identifies: bleeders, winners, fatigue signals
5. Generates: summary with recommendations
6. Delivers: to configured channel (Telegram/Slack/etc)
7. Waits: for user approval on any actions

### On-Demand (Interactive)
1. User asks a question ("how are my ads?")
2. Agent determines which report(s) to run
3. Pulls data via appropriate script
4. Interprets in context of benchmarks (ad-config.json)
5. Presents findings with actionable recommendations
6. If action needed: asks for explicit approval

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

### Actions Require Approval
Any action that affects spend requires explicit user confirmation:
- Pausing/resuming ads
- Budget changes
- Status changes

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
