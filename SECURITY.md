# Security Policy

## Reporting a vulnerability

Please do **not** report security issues in public GitHub issues.

If you find a vulnerability, credential leak, unsafe Meta Ads action path, or tracking/CAPI issue that could expose customer data, report it privately to the repository maintainer.

Include:

- A short description of the issue
- Steps to reproduce
- Affected files or commands
- Whether the issue can mutate ads, budgets, creatives, tracking, or CAPI events
- Any suggested fix

## Secrets and ad-account safety

This project can interact with Meta ad accounts. Treat these values as secrets:

- `ACCESS_TOKEN`
- `AD_ACCOUNT_ID` when tied to private account context
- `BUSINESS_ID`
- Pixel IDs and CAPI test/event details when account-specific
- Any exported Ads API response containing customer or campaign data

Never commit `.env`, `ad-config.json`, local logs, `workspace/`, `memory/`, or API responses containing private account data.

## Automation safety

Headless jobs must remain read-only. Cron and CI must not:

- Pause or resume ads
- Change budgets
- Create or upload ads
- Send production CAPI events
- Change tracking or attribution configuration

All spend-affecting or attribution-affecting actions require an interactive user approval step.
