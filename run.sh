#!/usr/bin/env bash
# Meta Ads Copilot — Report Runner
#
# Usage:
#   ./run.sh daily-check           # The 5 Daily Questions
#   ./run.sh overview              # Account overview
#   ./run.sh bleeders              # Find underperformers
#   ./run.sh winners               # Find top performers
#   ./run.sh fatigue               # Creative fatigue check
#   ./run.sh efficiency            # Budget efficiency ranking
#   ./run.sh recommend             # Budget shift recommendations
#
# Options:
#   --account act_123              # Override ad account
#   --preset last_30d              # Date range (last_7d, last_30d, etc.)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-daily-check}"

# Route to the right skill script
case "$MODE" in
  daily-check|daily|check|5questions|overview|campaigns|top-creatives|creatives|bleeders|losers|winners|tops|fatigue-check|custom)
    shift 2>/dev/null || true
    bash "$SCRIPT_DIR/skills/meta-ads/scripts/meta-ads.sh" "$MODE" "$@"
    ;;
  fatigue|creative-monitor)
    shift 2>/dev/null || true
    bash "$SCRIPT_DIR/skills/ad-creative-monitor/scripts/creative-monitor.sh" fatigue-check "$@"
    ;;
  weekly-report|weekly)
    shift 2>/dev/null || true
    bash "$SCRIPT_DIR/skills/ad-creative-monitor/scripts/creative-monitor.sh" weekly-report "$@"
    ;;
  track-ad|track)
    shift 2>/dev/null || true
    bash "$SCRIPT_DIR/skills/ad-creative-monitor/scripts/creative-monitor.sh" track-ad "$@"
    ;;
  efficiency|budget)
    shift 2>/dev/null || true
    bash "$SCRIPT_DIR/skills/budget-optimizer/scripts/budget-optimizer.sh" efficiency "$@"
    ;;
  recommend|optimize)
    shift 2>/dev/null || true
    bash "$SCRIPT_DIR/skills/budget-optimizer/scripts/budget-optimizer.sh" recommend "$@"
    ;;
  pacing)
    shift 2>/dev/null || true
    bash "$SCRIPT_DIR/skills/budget-optimizer/scripts/budget-optimizer.sh" pacing "$@"
    ;;
  *)
    echo "Meta Ads Copilot"
    echo ""
    echo "Usage: ./run.sh <command> [options]"
    echo ""
    echo "Reports:"
    echo "  daily-check    The 5 Daily Questions (start here)"
    echo "  overview       Account overview with campaign breakdown"
    echo "  campaigns      List active campaigns"
    echo "  bleeders       Find ads bleeding money"
    echo "  winners        Find top performing ads"
    echo "  fatigue        Creative fatigue scan"
    echo "  weekly         Weekly creative health report"
    echo "  efficiency     Budget efficiency ranking"
    echo "  recommend      Budget shift recommendations"
    echo "  pacing         Spend pacing check"
    echo "  track-ad ID    Track specific ad over time"
    echo ""
    echo "Options:"
    echo "  --account act_123    Override ad account"
    echo "  --preset last_30d    Date range"
    echo ""
    echo "Quick start: ./run.sh daily-check"
    ;;
esac
