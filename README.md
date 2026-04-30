# Meta Ads Copilot

An open-source AI ad manager that replaces 20 minutes of Ads Manager clicking with a 2-minute summary over coffee.

A standalone multi-file **Hermes Agent** skill pack for Meta ads monitoring, creative fatigue detection, budget recommendations, copy generation, ad upload workflows, and Pixel/CAPI audits.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hermes Agent](https://img.shields.io/badge/Works%20with-Hermes%20Agent-blue)](https://github.com/NOETIC-AGI/hermes-agent)

---

**Monitor → Detect Fatigue → Find Winners → Shift Budget → Generate Copy → Upload to Meta → Repeat**

This kit automates your entire Meta Ads workflow:

- **Morning briefing** — Spend pacing, active campaigns, 7-day trends
- **Find bleeders** — Ads with high spend + low CTR bleeding your budget
- **Spot winners** — Top performers ready to scale
- **Detect fatigue** — CTR declining, frequency climbing, CPC rising
- **Generate copy** — AI writes ad copy matched to your actual image creatives
- **Upload to Meta** — Push new ads straight to your account via Graph API
- **Pixel + CAPI audit** — Audit your tracking setup, test server-side events, optimize for 9.3+ Event Match Quality
- **Take action** — Pause, resume, adjust budgets (always with your approval)

The result: A full ad management loop -- from monitoring to creative refresh to tracking optimization -- without opening Ads Manager.

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

# Install/configure the meta-ads CLI, then verify it
meta-ads auth status

# List ad accounts as JSON and choose one
meta-ads -o json ads adaccount list

# Copy config
cp .env.example .env
cp ad-config.example.json ad-config.json

# Edit .env with ACCESS_TOKEN, AD_ACCOUNT_ID, optional BUSINESS_ID / META_ADS_CLI
# Edit ad-config.json with your benchmarks
```

Install Hermes Agent if you do not already have it, then install the skills by copying the **full skill directories**:

```bash
# Install Hermes Agent and complete first-time setup
pip install hermes-agent
hermes setup

# Install/copy every skill directory, including bundled scripts/ and references/
mkdir -p ~/.hermes/skills/marketing
cp -R skills/* ~/.hermes/skills/marketing/

# Confirm Hermes can see all six Meta Ads Copilot skills
hermes skills list
```

You should see:

- `meta-ads`
- `ad-creative-monitor`
- `budget-optimizer`
- `ad-copy-generator`
- `ad-upload`
- `pixel-capi`

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
# Run all 5 questions locally
./run.sh daily-check

# Or run through Hermes Agent from this repo root
hermes chat --toolsets skills,terminal -q "/meta-ads Daily ads check"
```

---

## Skills

| Skill | What It Does |
|-------|-------------|
| `meta-ads` | Core reporting — daily checks, campaign insights, bleeders, winners, fatigue detection |
| `ad-creative-monitor` | Track creative performance over time, detect fatigue before it kills your ROAS |
| `budget-optimizer` | Analyze spend efficiency, recommend budget shifts between campaigns/adsets |
| `ad-copy-generator` | Generate ad copy matched to specific image creatives — analyzes the visual, writes copy that reinforces it, outputs `asset_feed_spec`-ready variants |
| `ad-upload` | Push images and copy straight to Meta via Graph API -- no Ads Manager copy-paste required |
| `pixel-capi` | Audit Meta Pixel + Conversions API setup, test server-side events, optimize Event Match Quality to 9.3+. Platform guides for Next.js, Shopify, WordPress, Webflow, GHL, ClickFunnels |

This is a standalone multi-file Hermes skill pack. Copy the full folders under `skills/` into a Hermes skills path; do not copy only `SKILL.md`, because several skills need their bundled `scripts/` and `references/` files.

### The Full Loop

The six skills chain together into a closed loop:

```
Monitor (meta-ads) → Detect fatigue (ad-creative-monitor) → Shift budget (budget-optimizer)
    → Generate new copy (ad-copy-generator) → Upload to Meta (ad-upload) → Monitor again

Pixel + CAPI (pixel-capi) runs alongside: audit tracking, test server events, optimize EMQ
```

No Ads Manager required at any step.

---

## How It Works

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Daily Check │───▶│   Patterns   │───▶│    Budget     │───▶│  Copy Gen    │───▶│   Upload     │
│  (5 questions│    │  & Fatigue   │    │  Optimizer    │    │  (per image) │    │  (Graph API) │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
       │                   │                   │                   │                   │
       ▼                   ▼                   ▼                   ▼                   ▼
 Spend pacing        Bleeders 🩸         Shift budget       Copy matched to      Push ads live
 Active campaigns    Winners 🏆          Scale winners      each creative        No Ads Manager
 7-day trends        Fatigue 😴          Cap losers         asset_feed_spec      Image + copy
```

**Morning briefing (read-only via Hermes cron):**
1. Run daily-check — flag bleeders, winners, and fatigue
2. Send strategist-level briefing with recommendations and new creative concepts
3. Save spend-affecting decisions for an interactive Hermes session where you can approve them

**When you need new creatives:**
1. Generate copy matched to specific image creatives
2. Review the variants
3. Upload directly to Meta — images, copy, and all — only after approval

**You (2 minutes over coffee):**
1. Read the summary
2. Approve/reject recommendations in an interactive session
3. Done.

---

## Running With Hermes Agent

Install Hermes Agent, then copy this pack's full skill directories into a Hermes skills path:

```bash
# Install Hermes Agent and complete first-time setup if needed
pip install hermes-agent
hermes setup

# From the meta-ads-kit repo root
mkdir -p ~/.hermes/skills/marketing
cp -R skills/* ~/.hermes/skills/marketing/

# Verify the installed skills
hermes skills list
```

Run interactively from the repo root so Hermes can also see `SOUL.md`, `AGENTS.md`, `ad-config.json`, `workspace/`, and `memory/`:

```bash
cd meta-ads-kit
hermes chat --toolsets skills,terminal
```

Then message it naturally:

- "How are my ads doing?"
- "Any bleeders I should pause?"
- "Which ads should I scale?"
- "Check for creative fatigue"
- "Show me performance by age and gender"
- "Write copy for this image"
- "Audit my Pixel/CAPI setup"
- "Pause ad 12345678"

Hermes handles orchestration, interprets the data, and must ask before taking any spend-affecting or attribution-affecting action.

### Automate Read-Only Briefings

Create a Hermes cron briefing with the installed reporting skills and `--workdir` pointing to this repo:

```bash
hermes cron create "0 8 * * *" \
  "Run my daily Meta ads check. Report spend pacing, active campaigns, bleeders, winners, creative fatigue, and budget recommendations. Do not pause ads, change budgets, upload creatives, send production CAPI events, or take any spend-affecting or attribution-affecting action." \
  --name "Meta Ads Daily Briefing" \
  --skills "meta-ads,ad-creative-monitor,budget-optimizer" \
  --workdir "/path/to/meta-ads-kit" \
  --deliver telegram
```

Cron runs are headless and cannot collect approval. Use cron only for read-only reports and recommendations; perform pausing, budget changes, uploads, and production tracking changes in an interactive Hermes session.

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

You can also tell Hermes your benchmarks conversationally during an interactive session and ask it to use or update `ad-config.json`.

Set `ACCESS_TOKEN`, `AD_ACCOUNT_ID`, optional `BUSINESS_ID`, and optional `META_ADS_CLI` in `.env` as described in [SETUP.md](SETUP.md). Direct Graph API upload and Pixel/CAPI workflows use the same `ACCESS_TOKEN`.

---

## Cost

| Tool | Monthly Cost |
|------|-------------|
| meta-ads CLI | Free/local installed CLI |
| Meta API | Free (your own ad account) |
| Hermes Agent | Free/open source |
| Model/API usage | Depends on your configured model provider |

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
│   ├── meta-ads/             # Core reporting & actions
│   ├── ad-creative-monitor/  # Creative fatigue tracking
│   ├── budget-optimizer/     # Spend efficiency analysis
│   ├── ad-copy-generator/    # AI copy matched to image creatives
│   ├── ad-upload/            # Push ads to Meta via Graph API
│   └── pixel-capi/           # Pixel + CAPI audit, testing, EMQ optimization
│       ├── scripts/          # pixel-audit, pixel-setup, capi-test, capi-send, emq-check
│       └── references/       # Complete pixel + CAPI knowledge base
├── SOUL.md                # Project persona/context for Hermes sessions
├── AGENTS.md              # Agent instructions
└── SPEC.md                # Full system spec
```

---

## Contributing

This is open source. PRs welcome.

Ideas for contribution:

- Google Ads support
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
