#!/usr/bin/env bash
# doctor.sh — read-only setup checks for Meta Ads Kit.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
META_ADS_BIN="${META_ADS_CLI:-meta-ads}"
FAILURES=0
WARNINGS=0

ok() { printf '✅ %s\n' "$*"; }
warn() { printf '⚠️  %s\n' "$*"; WARNINGS=$((WARNINGS + 1)); }
fail() { printf '❌ %s\n' "$*"; FAILURES=$((FAILURES + 1)); }
info() { printf 'ℹ️  %s\n' "$*"; }

check_cmd() {
  local cmd="$1" required="${2:-required}"
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd found: $(command -v "$cmd")"
  elif [[ "$required" == "required" ]]; then
    fail "$cmd not found"
  else
    warn "$cmd not found"
  fi
}

printf 'Meta Ads Kit Doctor\n'
printf 'Repo: %s\n\n' "$REPO_ROOT"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$ENV_FILE"; set +a
  ok ".env found"
else
  warn ".env not found; copy .env.example to .env for local runs and cron"
fi

META_ADS_BIN="${META_ADS_CLI:-meta-ads}"

printf '\nRequired commands\n'
check_cmd bash
check_cmd jq
check_cmd curl
check_cmd "$META_ADS_BIN"
check_cmd hermes optional
check_cmd crontab optional
if command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1; then
  ok "SHA-256 tool found"
else
  fail "Need sha256sum or shasum for Pixel/CAPI hashing scripts"
fi
check_cmd bc optional

printf '\nConfiguration\n'
if [[ -n "${ACCESS_TOKEN:-}" ]]; then
  ok "ACCESS_TOKEN is set (value hidden)"
else
  warn "ACCESS_TOKEN is not set; reporting via authenticated meta-ads may still work, but Graph API upload/Pixel/CAPI scripts require it"
fi

if [[ -n "${AD_ACCOUNT_ID:-}" ]]; then
  ok "AD_ACCOUNT_ID is set to ${AD_ACCOUNT_ID}"
else
  warn "AD_ACCOUNT_ID is not set; run: $META_ADS_BIN -o json ads adaccount list"
fi

printf '\nMeta Ads CLI\n'
if command -v "$META_ADS_BIN" >/dev/null 2>&1; then
  if "$META_ADS_BIN" auth status >/tmp/meta-ads-kit-auth-status.$$ 2>&1; then
    ok "meta-ads auth status passed"
    sed 's/token: .*)/token: hidden)/' /tmp/meta-ads-kit-auth-status.$$ | sed 's/^/   /'
  else
    warn "meta-ads auth status failed"
    sed 's/^/   /' /tmp/meta-ads-kit-auth-status.$$ || true
  fi
  rm -f /tmp/meta-ads-kit-auth-status.$$

  if "$META_ADS_BIN" -o json ads adaccount list >/tmp/meta-ads-kit-adaccounts.$$ 2>/tmp/meta-ads-kit-adaccounts.err.$$; then
    count=$(jq 'length' /tmp/meta-ads-kit-adaccounts.$$ 2>/dev/null || echo '?')
    ok "ad account list returned $count account(s)"
  else
    warn "could not list ad accounts"
    sed 's/^/   /' /tmp/meta-ads-kit-adaccounts.err.$$ || true
  fi
  rm -f /tmp/meta-ads-kit-adaccounts.$$ /tmp/meta-ads-kit-adaccounts.err.$$
fi

printf '\nHermes skills\n'
missing_skills=0
for skill in meta-ads ad-creative-monitor budget-optimizer ad-copy-generator ad-upload pixel-capi; do
  if [[ -d "$HOME/.hermes/skills/marketing/$skill" ]]; then
    ok "$skill installed"
  else
    warn "$skill not installed in ~/.hermes/skills/marketing"
    missing_skills=$((missing_skills + 1))
  fi
done
if [[ "$missing_skills" -gt 0 ]]; then
  info "Install/update with: scripts/install-hermes-skills.sh"
fi

printf '\nLocal scripts\n'
if bash -n "$REPO_ROOT/run.sh" "$REPO_ROOT"/scripts/*.sh "$REPO_ROOT"/skills/*/scripts/*.sh; then
  ok "shell syntax check passed"
else
  fail "shell syntax check failed"
fi

if [[ -x "$REPO_ROOT/run.sh" ]]; then
  ok "run.sh is executable"
else
  warn "run.sh is not executable; run: chmod +x run.sh scripts/*.sh skills/*/scripts/*.sh"
fi

printf '\nSummary\n'
printf 'Failures: %s\nWarnings: %s\n' "$FAILURES" "$WARNINGS"
if [[ "$FAILURES" -gt 0 ]]; then
  exit 1
fi
