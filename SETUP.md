# Meta Ads Copilot — Setup Guide

Get your Hermes-powered AI ad manager running in 10 minutes.

---

## Step 1: Install and Verify `meta-ads`

This kit uses the installed `meta-ads` CLI for Meta Ads or Meta Ads MCP for reporting. Docs prefer the `meta-ads` command, not any symlink.

For MCP use the followiing URL for ads MCP server across all currently supported AI agents is:

https://mcp.facebook.com/ads

You should be prompted to log into facebook ads with your uer credentials. See Facebook information here: https://www.facebook.com/business/help/1456422242197840

For the meta ads CLI, refer to thee documentation here: https://developers.facebook.com/documentation/ads-commerce/ads-ai-connectors/ads-cli/setup/get-started

```bash
meta-ads auth status
```

If the command is installed outside your `PATH`, set an override in `.env`:

```bash
META_ADS_CLI=/absolute/path/to/meta-ads
```

The wrapper can load credentials from `~/.hermes/envs/meta-ads/.env`. Keep real tokens out of git; 1Password or another secrets manager is a safe storage option.

---

## Step 2: Configure Meta Credentials

Copy the templates:

```bash
cp .env.example .env
cp ad-config.example.json ad-config.json
```

Edit `.env`:

| Variable | Used For |
|----------|----------|
| `ACCESS_TOKEN` | Meta Graph API token used by `meta-ads` CLI, ad upload, copy lookup, and Pixel/CAPI direct Graph workflows |
| `AD_ACCOUNT_ID` | Default ad account, e.g. `act_123456789` |
| `BUSINESS_ID` | Optional Business Manager ID for business-scoped workflows |
| `META_ADS_CLI` | Optional path/name override for the installed `meta-ads` binary |

Tokens need `ads_read` and `read_insights` for monitoring. Add `ads_management` only for interactive sessions where you want approved spend-affecting actions or Graph API ad creation.

---

## Step 3: Choose Your Ad Account

List your available ad accounts with the JSON flag before the subcommand:

```bash
meta-ads -o json ads adaccount list
```

Set the selected account in `.env`:

```bash
AD_ACCOUNT_ID=act_YOUR_ACCOUNT_ID
```

---

## Step 4: Configure Benchmarks

Edit `ad-config.json` with your targets:

```json
{
  "account": {
    "id": "act_YOUR_ACCOUNT_ID",
    "name": "Your Brand Name"
  },
  "benchmarks": {
    "target_cpa": 25.00,
    "target_roas": 3.0,
    "max_frequency": 3.5,
    "min_ctr": 1.0,
    "max_cpc": 2.50
  }
}
```

**Don't know your benchmarks?** Leave the defaults — the agent will learn them from your data.

---

## Step 5: Test Local Reporting

```bash
chmod +x run.sh
./run.sh daily-check
```

You should see the 5 Daily Questions with your actual ad data.

---

## Step 6: Install the Hermes Skill Pack

Install Hermes Agent if needed, then copy each complete skill directory into a Hermes skills path. This repository is a standalone multi-file Hermes skill pack; do not copy only `SKILL.md`, because some skills require bundled `scripts/` and `references/` files.

```bash
# Install Hermes Agent and complete first-time setup
pip install hermes-agent
hermes setup

# From the meta-ads-kit repo root
mkdir -p ~/.hermes/skills/marketing
cp -R skills/* ~/.hermes/skills/marketing/

# Confirm Hermes can see all six skills
hermes skills list
```

Confirm these skills are listed:

- `meta-ads`
- `ad-creative-monitor`
- `budget-optimizer`
- `ad-copy-generator`
- `ad-upload`
- `pixel-capi`

---

## Step 7: Run Interactively With Hermes

Start Hermes from the repo root so it can see `SOUL.md`, `AGENTS.md`, `ad-config.json`, `workspace/`, and `memory/`:

```bash
cd /path/to/meta-ads-kit
hermes chat --toolsets skills,terminal
```

Then message the agent naturally:

- "How are my ads doing?"
- "Any bleeders?"
- "Daily check"
- "Check creative fatigue"
- "Write copy for this image"
- "Audit my Pixel/CAPI setup"

You can also run a one-shot smoke test:

```bash
hermes chat --toolsets skills,terminal -q "/meta-ads Daily ads check"
```

Hermes should ask before pausing ads, changing budgets, uploading ads, sending production CAPI events, or changing tracking configuration.

---

## Step 8: Automate Read-Only Morning Briefings

Hermes cron is for headless reports and recommendations only. It cannot collect approvals, so do not use cron for pausing ads, changing budgets, uploading creatives, or production tracking changes.

```bash
hermes cron create "0 8 * * *" \
  "Run my daily Meta ads check. Report spend pacing, active campaigns, bleeders, winners, creative fatigue, and budget recommendations. Do not pause ads, change budgets, upload creatives, send production CAPI events, or take any spend-affecting or attribution-affecting action." \
  --name "Meta Ads Daily Briefing" \
  --skills "meta-ads,ad-creative-monitor,budget-optimizer" \
  --workdir "/path/to/meta-ads-kit" \
  --deliver telegram
```

Use your preferred delivery target for `--deliver`. Keep `--workdir` pointed at this repo so cron can access project context and memory paths.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `meta-ads: command not found` | Install/configure the `meta-ads` CLI or set `META_ADS_CLI=/absolute/path/to/meta-ads` |
| Authentication/config check fails | Verify `ACCESS_TOKEN` is set and run `meta-ads auth status` |
| "No ad accounts found" | Make sure the token's user/system user has ad account access; run `meta-ads -o json ads adaccount list` |
| No data returned | Check that campaigns have been running in the selected time period |
| Rate limited | Wait a few minutes and retry |
| Hermes skill not listed | Copy the full directory from `skills/<skill-name>/` into your Hermes skills path, then rerun `hermes skills list` |
| Script/reference not found | Reinstall by copying the full skill folder, not just `SKILL.md` |
| Cron cannot find repo files | Add `--workdir /path/to/meta-ads-kit` to the cron job |
| Cron does not run automatically | Confirm the Hermes gateway/cron service is running in your Hermes environment |
| Missing Graph API token | Set `ACCESS_TOKEN` for upload, copy lookup, and Pixel/CAPI workflows |

### Check Everything

```bash
meta-ads auth status
meta-ads -o json ads adaccount list
meta-ads -o json ads campaign list
hermes skills list
```

This checks `meta-ads` configuration and confirms Hermes can see the installed skill pack.

---

## Permissions Needed

| Permission | Required For |
|-----------|-------------|
| `ads_read` | Reading campaign data, insights |
| `read_insights` | Performance metrics |
| `ads_management` | Pausing/resuming ads, budget changes, ad creation, and CAPI event send permissions where required |

`ads_read` + `read_insights` are enough for monitoring only. Add `ads_management` only if you want interactive sessions to take approved action or create/upload ads.
