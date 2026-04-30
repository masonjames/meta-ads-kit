#!/usr/bin/env bash
# install-cron.sh — install/remove/show a daily read-only Meta Ads Kit report cron
#
# Examples:
#   scripts/install-cron.sh --show
#   scripts/install-cron.sh --install
#   scripts/install-cron.sh --install --time 08:00 --command daily-check
#   scripts/install-cron.sh --remove
#
# Internal cron entrypoint:
#   scripts/install-cron.sh --run daily-check

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_SH="$REPO_ROOT/run.sh"
LOG_DIR="${META_ADS_KIT_LOG_DIR:-$HOME/.cache/meta-ads-kit/logs}"
MARKER_ID="meta-ads-kit:$REPO_ROOT"
BEGIN_MARKER="# BEGIN META ADS KIT DAILY REPORT ($MARKER_ID)"
END_MARKER="# END META ADS KIT DAILY REPORT ($MARKER_ID)"
DEFAULT_TIME="08:00"
DEFAULT_COMMAND="daily-check"
ACTION="show"
SCHEDULE_TIME="$DEFAULT_TIME"
REPORT_COMMAND="$DEFAULT_COMMAND"

usage() {
  cat <<EOF
Meta Ads Kit cron installer

Usage:
  $0 --show [--time HH:MM] [--command COMMAND]
  $0 --install [--time HH:MM] [--command COMMAND]
  $0 --remove
  $0 --run COMMAND   # internal cron entrypoint

Options:
  --install          Install/update the daily cron entry. Default time: $DEFAULT_TIME.
  --remove           Remove this repo's Meta Ads Kit cron entry.
  --show             Show current entry and the entry that would be installed. No mutation.
  --time HH:MM       Local 24-hour time for daily cron, e.g. 08:00 or 17:30.
  --command COMMAND  Read-only run.sh command: daily-check, overview, campaigns,
                     top-creatives, bleeders, winners, fatigue-check, weekly,
                     efficiency, recommend, pacing, or custom.
  --run COMMAND      Internal: run the report now from cron-safe environment.
  -h, --help         Show this help.

Safety: cron jobs are read-only report jobs. Do not schedule commands that pause ads,
change budgets, upload creatives, send production CAPI events, or modify tracking.
EOF
}

allowed_command() {
  case "$1" in
    daily-check|daily|check|5questions|overview|campaigns|top-creatives|creatives|bleeders|losers|winners|tops|fatigue-check|fatigue|weekly-report|weekly|efficiency|budget|recommend|optimize|pacing|custom)
      return 0 ;;
    *) return 1 ;;
  esac
}

validate_time() {
  local value="$1"
  if [[ ! "$value" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
    echo "ERROR: --time must be HH:MM in 24-hour local time, e.g. 08:00" >&2
    exit 2
  fi
}

require_runtime() {
  if [[ ! -x "$RUN_SH" ]]; then
    echo "ERROR: $RUN_SH is missing or not executable. Run: chmod +x run.sh" >&2
    exit 1
  fi
  if ! command -v crontab >/dev/null 2>&1 && [[ "${1:-}" != "run" ]]; then
    echo "ERROR: crontab command not found on this system." >&2
    exit 1
  fi
}

current_crontab() {
  crontab -l 2>/dev/null || true
}

without_managed_block() {
  awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
    $0 == begin {skip=1; next}
    $0 == end {skip=0; next}
    skip != 1 {print}
  '
}

cron_line() {
  validate_time "$SCHEDULE_TIME"
  if ! allowed_command "$REPORT_COMMAND"; then
    echo "ERROR: unsupported --command '$REPORT_COMMAND'. Use --help for allowed commands." >&2
    exit 2
  fi

  local hour minute inner quoted_inner
  hour="${SCHEDULE_TIME%%:*}"
  minute="${SCHEDULE_TIME##*:}"
  # Strip a leading zero for cron readability; cron accepts both, but this avoids octal-looking output.
  hour="$((10#$hour))"
  minute="$((10#$minute))"

  inner="mkdir -p \"$LOG_DIR\" && cd \"$REPO_ROOT\" && \"$SCRIPT_DIR/install-cron.sh\" --run \"$REPORT_COMMAND\" >> \"$LOG_DIR/$REPORT_COMMAND.log\" 2>&1"
  printf -v quoted_inner '%q' "$inner"
  printf '%s %s * * * /bin/bash -lc %s\n' "$minute" "$hour" "$quoted_inner"
}

show_entry() {
  echo "Meta Ads Kit repo: $REPO_ROOT"
  echo "Log directory: $LOG_DIR"
  echo ""
  echo "Current managed cron entry:"
  current_crontab | awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
    $0 == begin {show=1}
    show == 1 {print}
    $0 == end {show=0}
  ' || true
  echo ""
  echo "Entry for --time $SCHEDULE_TIME --command $REPORT_COMMAND:"
  echo "$BEGIN_MARKER"
  cron_line
  echo "$END_MARKER"
}

install_entry() {
  require_runtime
  mkdir -p "$LOG_DIR"

  local tmp
  tmp="$(mktemp)"
  {
    current_crontab | without_managed_block
    echo "$BEGIN_MARKER"
    cron_line
    echo "$END_MARKER"
  } | sed '/^[[:space:]]*$/N;/^\n$/D' > "$tmp"

  crontab "$tmp"
  rm -f "$tmp"

  echo "Installed Meta Ads Kit daily read-only cron."
  echo "Schedule: $SCHEDULE_TIME local time"
  echo "Command: ./run.sh $REPORT_COMMAND"
  echo "Logs: $LOG_DIR/$REPORT_COMMAND.log"
  echo ""
  echo "Safety reminder: this cron entry runs reports only. It must not pause ads, change budgets, upload creatives, send production CAPI events, or change tracking."
}

remove_entry() {
  require_runtime
  local tmp
  tmp="$(mktemp)"
  current_crontab | without_managed_block > "$tmp"
  crontab "$tmp"
  rm -f "$tmp"
  echo "Removed this repo's Meta Ads Kit cron entry, if it existed."
}

run_report() {
  local command_name="$1"
  if ! allowed_command "$command_name"; then
    echo "ERROR: unsupported report command '$command_name'" >&2
    exit 2
  fi

  echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] Meta Ads Kit cron report starting: $command_name"
  cd "$REPO_ROOT"
  exec "$RUN_SH" "$command_name"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install) ACTION="install"; shift ;;
    --remove) ACTION="remove"; shift ;;
    --show) ACTION="show"; shift ;;
    --time) SCHEDULE_TIME="${2:-}"; shift 2 ;;
    --command) REPORT_COMMAND="${2:-}"; shift 2 ;;
    --run) ACTION="run"; REPORT_COMMAND="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$ACTION" in
  show) require_runtime; show_entry ;;
  install) install_entry ;;
  remove) remove_entry ;;
  run) run_report "$REPORT_COMMAND" ;;
  *) echo "ERROR: unknown action '$ACTION'" >&2; exit 2 ;;
esac
