# Meta Ads Copilot — Setup Guide

Get your AI ad manager running in 10 minutes.

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

## Step 4: Configure Benchmarks

```bash
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

---

## Step 5: Test It

```bash
chmod +x run.sh
./run.sh daily-check
```

You should see the 5 Daily Questions with your actual ad data.

---

## Step 6 (Optional): Run With OpenClaw

```bash
# Install OpenClaw if you haven't
npm install -g openclaw

# Start the agent
cd meta-ads-kit
openclaw start
```

Now message the agent naturally:
- "How are my ads doing?"
- "Any bleeders?"
- "Daily check"

### Automate Morning Briefings

Tell the agent:
> "Run my daily ads check every morning at 8am and send me the summary"

It'll set up a cron job and message you each morning with findings.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `social: command not found` | Run `npm install -g @vishalgojha/social-cli` |
| Authentication fails | Try `social auth login` again, check browser popup |
| "No ad accounts found" | Make sure your Facebook user has ad account access |
| No data returned | Check that campaigns have been running in the selected time period |
| Rate limited | Wait a few minutes and retry |

### Check Everything

```bash
social doctor
```

This runs diagnostics on your social-cli setup.

---

## Permissions Needed

| Permission | Required For |
|-----------|-------------|
| `ads_read` | Reading campaign data, insights |
| `ads_management` | Pausing/resuming ads, budget changes |
| `read_insights` | Performance metrics |

`ads_read` + `read_insights` are enough for monitoring only. Add `ads_management` if you want the agent to take action.
