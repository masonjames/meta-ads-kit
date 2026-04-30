## Summary

<!-- What changed and why? -->

## Type of change

- [ ] Documentation
- [ ] Read-only reporting / analysis
- [ ] Hermes skill behavior
- [ ] Setup / installer / cron
- [ ] Pixel/CAPI
- [ ] Spend-affecting or attribution-affecting workflow

## Safety checklist

- [ ] This does not commit secrets, account-private exports, logs, `.env`, or `ad-config.json`.
- [ ] Headless/cron behavior remains read-only.
- [ ] Any spend-affecting or attribution-affecting action requires explicit interactive approval.
- [ ] I copied full skill directories when testing, not only `SKILL.md`.

## Verification

```bash
bash -n run.sh scripts/*.sh skills/*/scripts/*.sh
git diff --check
scripts/doctor.sh
```

Paste relevant output here:

```text

```
