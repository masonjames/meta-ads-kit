---
name: ad-creative-monitor
description: "Track creative performance over time and detect fatigue before it kills ROAS. Monitors CTR decay, frequency creep, and CPC inflation at the ad level."
metadata:
  openclaw:
    emoji: "😴"
    user-invocable: true
    requires:
      tools: ["social"]
      env: []
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
./scripts/creative-monitor.sh fatigue-check

# Track specific ad over time
./scripts/creative-monitor.sh track-ad AD_ID

# Weekly creative health report
./scripts/creative-monitor.sh weekly-report
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

1. Pull ad-level insights with daily time increment (`--time-increment 1`)
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
