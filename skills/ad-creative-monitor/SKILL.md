---
name: ad-creative-monitor
description: "Track creative performance over time and detect fatigue before it kills ROAS. Monitors CTR decay, frequency creep, and CPC inflation at the ad level."
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
      - creative-fatigue
      - ad-creative
      - ctr-monitoring
      - performance-marketing
    related_skills:
      - meta-ads
      - budget-optimizer
      - ad-copy-generator
    requires_toolsets:
      - terminal
---

# Ad Creative Monitor — Catch Fatigue Early

Creative fatigue is the silent killer of ad accounts. CTR drops 0.1% per day, frequency ticks up, CPC quietly inflates — and by the time you notice in Ads Manager, you've burned through budget.

This skill watches for those signals daily and flags creatives that need rotation.

---

## How It Works

### Fatigue Signals (ranked by severity)

| Signal | Threshold | Severity |
|--------|-----------|----------|
| CTR dropping 3+ days in a row | >20% decline from peak | 🔴 Critical |
| Frequency above 3.5 | Audience seeing ad too often | 🟡 Warning |
| CPC rising 3+ days in a row | >15% increase from baseline | 🟡 Warning |
| Impressions declining | Ad losing delivery | 🟠 Monitor |

### The Check

```bash
# Run fatigue check
bash "${HERMES_SKILL_DIR}/scripts/creative-monitor.sh" fatigue-check

# Track specific ad over time
bash "${HERMES_SKILL_DIR}/scripts/creative-monitor.sh" track-ad AD_ID

# Weekly creative health report
bash "${HERMES_SKILL_DIR}/scripts/creative-monitor.sh" weekly-report
```

---

## Reports

### Fatigue Check
Daily scan of all active ads for fatigue signals.

```
Tell me: "Check for creative fatigue"
Or: "Are any ads getting stale?"
```

### Creative Leaderboard
Rank all active creatives by efficiency (CTR × spend volume).

```
Tell me: "Rank my creatives"
Or: "Which creatives are strongest?"
```

### Rotation Recommendations
Based on fatigue signals, recommend which creatives to pause and when new ones are needed.

```
Tell me: "What needs to be rotated?"
Or: "Which ads need fresh creative?"
```

---

## Invocation

1. Pull ad-level fields with daily time increment (`meta-ads -o json ads insights get --date-preset last_7d --time-increment daily --fields "ad_name,ad_id,date_start,impressions,clicks,ctr,cpc,frequency,spend"`)
2. Calculate day-over-day CTR, CPC, and frequency trends
3. Flag any ad showing fatigue signals
4. Compare against benchmarks in `ad-config.json`
5. Present findings with clear severity ratings
6. Recommend rotation schedule if fatigue detected
7. Log findings to `workspace/brand/learnings.md`

---

## Writes

| File | What it contains |
|------|-----------------|
| `workspace/brand/learnings.md` | Fatigue patterns, creative lifespan data |
