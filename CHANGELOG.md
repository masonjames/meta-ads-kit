# Changelog

All notable changes to Meta Ads Copilot will be documented in this file.

This project follows the spirit of [Keep a Changelog](https://keepachangelog.com/) and uses date-based unreleased notes until tagged releases begin.

## Unreleased

### Added

- First-time setup path for Hermes users installing this kit and the Meta Ads CLI together.
- `scripts/install-hermes-skills.sh` to copy the full multi-file skill directories into Hermes.
- `scripts/doctor.sh` for read-only setup checks: commands, credentials, Meta Ads CLI auth, ad account access, installed skills, and shell syntax.
- `scripts/install-cron.sh` for optional daily read-only local report cron jobs.
- Community health files for contributing and security guidance.

### Fixed

- Pixel/CAPI helper scripts now use the configured `ACCESS_TOKEN` instead of placeholder token text.
- Pixel/CAPI hashing helpers now work with either `sha256sum` or macOS `shasum -a 256`.
- Meta Ads action examples align with the installed CLI's `update --status ...` command shape.
