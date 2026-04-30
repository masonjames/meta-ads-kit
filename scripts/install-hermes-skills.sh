#!/usr/bin/env bash
# install-hermes-skills.sh — install this repo's Hermes skills locally.
#
# Usage:
#   scripts/install-hermes-skills.sh
#   scripts/install-hermes-skills.sh --dest ~/.hermes/skills/marketing
#   scripts/install-hermes-skills.sh --dry-run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$REPO_ROOT/skills"
DEST_DIR="$HOME/.hermes/skills/marketing"
DRY_RUN=0

usage() {
  cat <<EOF
Meta Ads Kit Hermes skill installer

Usage:
  $0 [--dest PATH] [--dry-run]

Options:
  --dest PATH    Destination skill category directory. Default: $DEST_DIR
  --dry-run      Print what would be copied without changing files.
  -h, --help     Show this help.

This copies each full skill directory, including bundled scripts/ and references/.
Do not copy only SKILL.md; several skills depend on sibling files.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest) DEST_DIR="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "ERROR: skills directory not found at $SOURCE_DIR" >&2
  exit 1
fi

printf 'Source:      %s\n' "$SOURCE_DIR"
printf 'Destination: %s\n' "$DEST_DIR"

for skill_dir in "$SOURCE_DIR"/*; do
  [[ -d "$skill_dir" ]] || continue
  [[ -f "$skill_dir/SKILL.md" ]] || {
    echo "ERROR: missing SKILL.md in $skill_dir" >&2
    exit 1
  }
  skill_name="$(basename "$skill_dir")"
  printf '  %s -> %s/%s\n' "$skill_name" "$DEST_DIR" "$skill_name"
done

if [[ "$DRY_RUN" == "1" ]]; then
  echo "Dry run only; no files copied."
  exit 0
fi

mkdir -p "$DEST_DIR"
for skill_dir in "$SOURCE_DIR"/*; do
  [[ -d "$skill_dir" ]] || continue
  skill_name="$(basename "$skill_dir")"
  rm -rf "$DEST_DIR/$skill_name"
  cp -R "$skill_dir" "$DEST_DIR/$skill_name"
done

echo "Installed Meta Ads Kit Hermes skills."

if command -v hermes >/dev/null 2>&1; then
  echo ""
  echo "Hermes skill list check:"
  hermes skills list | grep -E 'ad-copy-generator|ad-creative-monitor|ad-upload|budget-optimizer|meta-ads |pixel-capi' || true
else
  echo "Hermes CLI not found on PATH. Install Hermes Agent, then run: hermes skills list"
fi
