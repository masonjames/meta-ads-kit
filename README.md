# Meta Ads Copilot

An open-source AI ad manager that replaces 20 minutes of Ads Manager clicking with a 2-minute summary over coffee.

A standalone multi-file **Hermes Agent** skill pack for Meta ads monitoring, creative fatigue detection, budget recommendations, copy generation, ad upload workflows, and Pixel/CAPI audits via the Ads API or MCP.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hermes Agent](https://img.shields.io/badge/Works%20with-Hermes%20Agent-blue)](https://github.com/NOETIC-AGI/hermes-agent)
[Meta Ads AI Connector MCP](https://www.facebook.com/business/help/1456422242197840) · [Meta Ads CLI](https://developers.facebook.com/documentation/ads-commerce/ads-ai-connectors/ads-cli/setup/get-started)

---

**Monitor → Detect Fatigue → Find Winners → Shift Budget → Generate Copy → Upload to Meta → Repeat**

This kit helps with the full Meta Ads management loop:

- **Morning briefing** — spend pacing, active campaigns, 7-day trends
- **Find bleeders** — ads with high spend + low CTR bleeding your budget
- **Spot winners** — top performers ready to scale
- **Detect fatigue** — CTR declining, frequency climbing, CPC rising
- **Generate copy** — AI writes ad copy matched to your actual image creatives
- **Upload to Meta** — push new ads straight to your account via Graph API
- **Pixel + CAPI audit** — audit tracking, test server-side events, optimize Event Match Quality
- **Take action** — pause, resume, adjust budgets, or change tracking only after your approval

The result: a full ad management loop without opening Ads Manager for every check.

---

## Why This Exists

90% of ad management is pattern recognition. Spend trending up or down. CTR declining. CPA spiking. Winners emerging. Losers bleeding.

You don't need to stare at Ads Manager to spot these patterns. An AI agent can do it and tell you what matters.

---

## Quick Start

For complete setup, see [SETUP.md](SETUP.md). The short version:

```bash
git clone https://github.com/masonjames/meta-ads-kit.git
cd meta-ads-kit

# Create local config files
cp .env.example .env
cp ad-config.example.json ad-config.json

# Install the full Hermes skill directories, including scripts/ and references/
scripts/install-hermes-skills.sh

# Run a read-only setup check
scripts/doctor.sh
```

If `scripts/doctor.sh` reports that `meta-ads` is missing, install and authenticate the official Meta Ads CLI first. Then edit `.env` with `ACCESS_TOKEN`, `AD_ACCOUNT_ID`, optional `BUSINESS_ID`, and optional `META_ADS_CLI`.

Edit `ad-config.json` with your account benchmarks. Hermes should list all six skills: `meta-ads`, `ad-creative-monitor`, `budget-optimizer`, `ad-copy-generator`, `ad-upload`, and `pixel-capi`.

```bash
# Optional: install a local OS cron job for daily read-only data pulls at 08:00
scripts/install-cron.sh --show
scripts/install-cron.sh --install --time 08:00 --command daily-check
```

The OS cron helper only runs `./run.sh` and writes logs to `~/.cache/meta-ads-kit/logs/`. Use Hermes cron instead when you want an agent-authored briefing delivered to Telegram, Slack, or another Hermes channel.

---

## The 5 Daily Questions

The core daily check replaces Ads Manager tab-hopping:

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

Run Hermes from the repo root, or configure cron with `--workdir` pointing here, so `SOUL.md`, `AGENTS.md`, `ad-config.json`, `workspace/`, and `memory/` are available.

---

## Skills

| Skill | What It Does |
|-------|-------------|
| `meta-ads` | Core reporting — daily checks, campaign insights, bleeders, winners, fatigue detection |
| `ad-creative-monitor` | Track creative performance over time and detect fatigue before it kills ROAS |
| `budget-optimizer` | Analyze spend efficiency and recommend budget shifts between campaigns/ad sets |
| `ad-copy-generator` | Generate ad copy matched to specific image creatives, outputting `asset_feed_spec`-ready variants |
| `ad-upload` | Push images and copy to Meta via Graph API after approval |
| `pixel-capi` | Audit Meta Pixel + Conversions API, test server-side events, and improve Event Match Quality |

The six skills form a closed loop:

```text
Monitor (meta-ads) → Detect fatigue (ad-creative-monitor) → Shift budget (budget-optimizer)
    → Generate new copy (ad-copy-generator) → Upload to Meta (ad-upload) → Monitor again

Pixel + CAPI (pixel-capi) runs alongside: audit tracking, test server events, optimize EMQ.
```

---

## Running With Hermes Agent

After copying the full skill directories, start Hermes from this repo root:

```bash
hermes chat --toolsets skills,terminal
```

Then ask naturally:

- "How are my ads doing?"
- "Any bleeders I should pause?"
- "Which ads should I scale?"
- "Check for creative fatigue"
- "Show me performance by age and gender"
- "Write copy for this image"
- "Audit my Pixel/CAPI setup"

Hermes handles orchestration and must ask before any spend-affecting or attribution-affecting action, including pausing/resuming ads, changing budgets, launching ads, sending production CAPI events, or changing tracking configuration.

---

## Automation

There are two safe automation modes:

1. **Local OS cron (`scripts/install-cron.sh`)** — recommended when you want `./run.sh` to pull daily read-only data and keep a local log available at `~/.cache/meta-ads-kit/logs/`.
2. **Hermes cron (`hermes cron create`)** — recommended when you want Hermes to synthesize and deliver an agent-authored briefing to a chat/channel.

Both modes are read-only. Headless scheduled jobs cannot collect approval, so they must never pause ads, change budgets, upload creatives, send production CAPI events, or change tracking configuration.

Install the local OS cron daily at 08:00:

```bash
scripts/install-cron.sh --show
scripts/install-cron.sh --install --time 08:00 --command daily-check
```

Manage it later:

```bash
scripts/install-cron.sh --show
scripts/install-cron.sh --remove
```

Use [SETUP.md](SETUP.md) for the full Hermes cron command. At minimum, point `--workdir` at this repo and include the reporting skills:

```bash
hermes cron create "0 8 * * *" \
  "Run my daily Meta ads check. Report recommendations only; do not take spend-affecting or attribution-affecting action." \
  --skills "meta-ads,ad-creative-monitor,budget-optimizer" \
  --workdir "/path/to/meta-ads-kit"
```

---

## Configuration

Local configuration is intentionally file-based:

- `.env.example` → copy to `.env` and set `ACCESS_TOKEN`, `AD_ACCOUNT_ID`, optional `BUSINESS_ID`, and optional `META_ADS_CLI`
- `ad-config.example.json` → copy to `ad-config.json` and set account benchmarks/alerts
- `workspace/` → runtime brand context and campaign artifacts
- `memory/` → daily notes and learnings

See [SETUP.md](SETUP.md) for detailed credential, account, benchmark, and troubleshooting steps.

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

## Project Map

- `README.md` — overview and short start guide
- `SETUP.md` — detailed setup, cron, credentials, and troubleshooting
- `AGENTS.md` — runtime instructions and approval gates for agents
- `SOUL.md` — project persona/context for Hermes sessions
- `SPEC.md` — full system spec
- `run.sh` — local report runner
- `scripts/install-hermes-skills.sh` — copies all bundled skills into `~/.hermes/skills/marketing/`
- `scripts/doctor.sh` — read-only first-run setup checker
- `scripts/install-cron.sh` — installs/removes the optional daily OS cron report
- `skills/` — six Hermes skill directories with their bundled scripts/references

---

MIT License. Use it, fork it, build on it.

Original source for OpenClaw by [Matt Berman](https://twitter.com/themattberman).

---

Stop babysitting Ads Manager. Let your AI copilot do the watching.

Star the repo if this helps. It tells me to keep building.
