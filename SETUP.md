# Meta Ads Copilot — Setup Guide

Get your Hermes-powered AI ad manager running in 10 minutes.

---

## Step 1: Install social-cli

social-cli is the open-source engine that talks to the Meta Marketing API.

```bash
npm install -g @vishalgojha/social-cli
```

Verify it's installed:
```bash
social --version
```

---

## Step 2: Authenticate with Meta

```bash
social auth login
```

This opens your browser to authorize with Meta. You need:
- A Facebook account with access to your ad account
- Permission to read ad insights (most ad account admins have this)

### Advanced: Using a Meta App

If you have a Meta developer app:

```bash
social auth set-app --app-id YOUR_APP_ID --app-secret YOUR_APP_SECRET
social auth login --scopes ads_read,ads_management,read_insights
```

---

## Step 3: Set Your Ad Account

List your available ad accounts:
```bash
social marketing accounts
```

Set the default:
```bash
social marketing set-default-account act_YOUR_ACCOUNT_ID
```

Or set via environment variable:
```bash
export META_AD_ACCOUNT=act_YOUR_ACCOUNT_ID
```

---

## Step 4: Configure Benchmarks and Tokens

```bash
cp .env.example .env
cp ad-config.example.json ad-config.json
```

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

Edit `.env` if you use Graph API or Pixel/CAPI workflows:

| Variable | Used For |
|----------|----------|
| `META_AD_ACCOUNT` | Default ad account, optional if set through social-cli |
| `FACEBOOK_ACCESS_TOKEN` | Graph API copy lookup and ad upload workflows |
| `META_TOKEN` | Pixel/CAPI scripts, unless social-cli config provides a usable token |

Reporting workflows prefer social-cli authentication. Upload and Pixel/CAPI workflows may need explicit token variables.

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
| `social: command not found` | Run `npm install -g @vishalgojha/social-cli` |
| Authentication fails | Try `social auth login` again, check browser popup |
| "No ad accounts found" | Make sure your Facebook user has ad account access |
| No data returned | Check that campaigns have been running in the selected time period |
| Rate limited | Wait a few minutes and retry |
| Hermes skill not listed | Copy the full directory from `skills/<skill-name>/` into your Hermes skills path, then rerun `hermes skills list` |
| Script/reference not found | Reinstall by copying the full skill folder, not just `SKILL.md` |
| Cron cannot find repo files | Add `--workdir /path/to/meta-ads-kit` to the cron job |
| Cron does not run automatically | Confirm the Hermes gateway/cron service is running in your Hermes environment |
| Missing Graph API token | Set `FACEBOOK_ACCESS_TOKEN` for upload/copy lookup workflows or `META_TOKEN` for Pixel/CAPI workflows |

### Check Everything

```bash
social doctor
hermes skills list
```

This checks social-cli diagnostics and confirms Hermes can see the installed skill pack.

---

## Permissions Needed

| Permission | Required For |
|-----------|-------------|
| `ads_read` | Reading campaign data, insights |
| `ads_management` | Pausing/resuming ads, budget changes, ad creation |
| `read_insights` | Performance metrics |

`ads_read` + `read_insights` are enough for monitoring only. Add `ads_management` only if you want interactive sessions to take approved action.
