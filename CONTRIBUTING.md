# Contributing

Thanks for helping improve Meta Ads Copilot. This repository is a standalone Hermes Agent skill pack plus local helper scripts for the Meta Ads CLI.

## Local setup

```bash
git clone https://github.com/masonjames/meta-ads-kit.git
cd meta-ads-kit
cp .env.example .env
cp ad-config.example.json ad-config.json
scripts/install-hermes-skills.sh --dry-run
scripts/doctor.sh
```

Do not commit `.env`, `ad-config.json`, tokens, account-specific exports, or files under `workspace/`, `memory/`, or `.meta-ads-kit/`.

## Development checks

Run these before opening a PR:

```bash
bash -n run.sh scripts/*.sh skills/*/scripts/*.sh
git diff --check
scripts/doctor.sh
```

If you change skill scripts, verify the installed skill path too:

```bash
scripts/install-hermes-skills.sh
bash ~/.hermes/skills/marketing/meta-ads/scripts/meta-ads.sh campaigns
```

Use read-only commands for tests. Do not pause ads, change budgets, upload creatives, send production CAPI events, or change tracking in automated tests.

## PR expectations

- Keep setup docs copy-pasteable for first-time Hermes users.
- Preserve explicit approval gates for all spend-affecting or attribution-affecting actions.
- Prefer Meta Ads CLI reporting commands for read-only workflows.
- Keep multi-file skills intact; do not document copying only `SKILL.md`.
- Include verification output in the PR description.
