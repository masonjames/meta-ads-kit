# Meta Ads Copilot

An open-source AI ad manager that replaces 20 minutes of Ads Manager clicking with a 2-minute summary over coffee.

Built with [OpenClaw](https://openclaw.ai) — the AI agent framework.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![OpenClaw](https://img.shields.io/badge/Built%20with-OpenClaw-blue)](https://openclaw.ai)

---

**Daily Check → Fatigue Alerts → Bleeders & Winners → Budget Recommendations → Action (with approval)**

This kit automates your daily Meta Ads management:

- **Morning briefing** — Spend pacing, active campaigns, 7-day trends
- **Find bleeders** — Ads with high spend + low CTR bleeding your budget
- **Spot winners** — Top performers ready to scale
- **Detect fatigue** — CTR declining, frequency climbing, CPC rising
- **Take action** — Pause, resume, adjust budgets (always with your approval)

The result: A daily ad management routine that used to take 20+ minutes now takes 2.

---

## Why This Exists

I've spent 20 years in marketing. Scaled Fireball Whisky from one state to a billion-dollar global brand. Ran campaigns for Heineken, Hennessy, Buffalo Trace. Now I run [Emerald Digital](https://emerald.digital), an AI-first marketing agency.

Here's what I learned: 90% of ad management is pattern recognition. Spend trending up or down. CTR declining (creative fatigue). CPA spiking (audience exhaustion). Winners emerging. Losers bleeding.

You don't need to stare at Ads Manager to spot these patterns. An AI agent can do it and tell you what matters.

I'm open-sourcing this because every founder running Meta ads deserves a copilot.

---

## Quick Start

```bash
git clone https://github.com/themattberman/meta-ads-kit.git
cd meta-ads-kit

# Install social-cli (the engine under the hood)
npm install -g @vishalgojha/social-cli

# Authenticate with Meta
social auth login

# Set your default ad account
social marketing accounts
social marketing set-default-account act_YOUR_ACCOUNT_ID

# Copy config
cp .env.example .env
cp ad-config.example.json ad-config.json

# Edit ad-config.json with your benchmarks
```

See [SETUP.md](SETUP.md) for detailed instructions.

---

## The 5 Daily Questions

The core of the system. Five questions that replace Ads Manager:

| # | Question | What It Tells You |
|---|----------|-------------------|
| 1 | Am I on track? | Today's spend vs. pacing expectations |
| 2 | What's running? | Active campaigns at a glance |
| 3 | How's performance? | 7-day metrics by campaign |
| 4 | Who's winning/losing? | Ad-level performance sorted |
| 5 | Any fatigue? | CTR trends, frequency, CPC movement |

```bash
# Run all 5 questions
./run.sh daily-check

# Or with OpenClaw agent
openclaw start
# Then message: "Daily ads check"
```

---

## Skills

| Skill | What It Does |
|-------|-------------|
| `meta-ads` | Core reporting — daily checks, campaign insights, bleeders, winners, fatigue detection |
| `ad-creative-monitor` | Track creative performance over time, detect fatigue before it kills your ROAS |
| `budget-optimizer` | Analyze spend efficiency, recommend budget shifts between campaigns/adsets |

Each skill can run standalone or as part of the daily routine.

---

## How It Works

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Daily Check   │────▶│   Find Patterns │────▶│  Recommendations│
│   (5 questions) │     │   (AI analysis) │     │  (your approval)│
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │                       │
        ▼                       ▼                       ▼
  Spend pacing            Bleeders 🩸              Pause losers
  Active campaigns        Winners 🏆              Scale winners
  7-day trends            Fatigue 😴              Shift budget
  Ad performance          Anomalies ⚠️            New creatives
```

**Morning (automated via cron):**
1. Run daily-check
2. Flag bleeders (CTR < 1%, frequency > 3.5, CPA > threshold)
3. Flag winners (top CTR, low CPC, scaling headroom)
4. Send summary to Telegram/Slack/wherever

**You (2 minutes over coffee):**
1. Read the summary
2. Approve/reject recommendations
3. Done.

---

## Running With OpenClaw

This kit is built for [OpenClaw](https://openclaw.ai), an open-source AI agent framework.

```bash
# Install OpenClaw
npm install -g openclaw

# Set up the agent
cd meta-ads-kit
openclaw start
```

Then just message it naturally:

- "How are my ads doing?"
- "Any bleeders I should pause?"
- "Which ads should I scale?"
- "Check for creative fatigue"
- "Show me performance by age and gender"
- "Pause ad 12345678"

The agent handles the orchestration, interprets the data, and asks before taking any action.

### Automate It

Set up a daily cron in OpenClaw:

```
"Run my daily ads check every morning at 8am and send me the summary"
```

The agent will run the 5 questions, analyze the results, and message you with findings + recommendations. You approve from your phone.

---

## Configuration

Edit `ad-config.json` to set your benchmarks:

```json
{
  "account": {
    "id": "act_123456789",
    "name": "My Brand"
  },
  "benchmarks": {
    "target_cpa": 25.00,
    "target_roas": 3.0,
    "max_frequency": 3.5,
    "min_ctr": 1.0,
    "max_cpc": 2.50
  },
  "alerts": {
    "bleeder_ctr_threshold": 1.0,
    "bleeder_frequency_threshold": 3.5,
    "fatigue_ctr_drop_pct": 20,
    "spend_pace_alert_pct": 15
  },
  "reporting": {
    "default_preset": "last_7d",
    "timezone": "America/New_York"
  }
}
```

Or just tell the OpenClaw agent your benchmarks conversationally — it'll figure it out.

---

## Cost

| Tool | Monthly Cost |
|------|-------------|
| social-cli | Free (open source) |
| Meta API | Free (your own ad account) |
| OpenClaw | Free (open source) |
| **Total** | **$0/mo** |

Your Meta ad spend is separate — this kit just helps you manage it smarter.

---

## Project Structure

```
meta-ads-kit/
├── README.md              # You're here
├── SETUP.md               # Detailed setup guide
├── run.sh                 # Report runner
├── .env.example           # Environment template
├── ad-config.example.json # Benchmarks template
├── skills/
│   ├── meta-ads/          # Core reporting & actions
│   ├── ad-creative-monitor/  # Creative fatigue tracking
│   └── budget-optimizer/  # Spend efficiency analysis
├── SOUL.md                # Agent personality (for OpenClaw)
├── AGENTS.md              # Agent instructions
└── SPEC.md                # Full system spec
```

---

## Contributing

This is open source. PRs welcome.

Ideas for contribution:

- Google Ads support (social-cli may add this)
- Creative performance dashboards
- Automated A/B test analysis
- Multi-account agency mode
- Slack/Discord notification integrations

---

MIT License. Use it, fork it, build on it.

---

Built by [Matt Berman](https://twitter.com/themattberman).

- 🐦 Twitter/X: [@themattberman](https://twitter.com/themattberman)
- 📰 Newsletter: [Big Players](https://bigplayers.co)
- 🏢 Agency: [Emerald Digital](https://emerald.digital)

---

Stop babysitting Ads Manager. Let your AI copilot do the watching.

Star the repo if this helps. It tells me to keep building.
