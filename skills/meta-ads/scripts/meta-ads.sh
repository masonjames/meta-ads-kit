#!/usr/bin/env bash
# meta-ads.sh — Pull Meta Ads data via social-cli
#
# Usage:
#   meta-ads.sh daily-check [--account act_123]
#   meta-ads.sh overview [--account act_123] [--preset last_7d]
#   meta-ads.sh campaigns [--account act_123] [--status ACTIVE]
#   meta-ads.sh top-creatives [--account act_123] [--preset last_7d] [--limit 10]
#   meta-ads.sh bleeders [--account act_123] [--preset last_7d] [--cpa-threshold 50]
#   meta-ads.sh winners [--account act_123] [--preset last_7d]
#   meta-ads.sh fatigue-check [--account act_123]
#   meta-ads.sh custom [--account act_123] [--level ad] [--fields ...] [--breakdowns ...]

set -euo pipefail

# Check social-cli is installed
if ! command -v social &>/dev/null; then
  echo "ERROR: social-cli not installed. Run: npm install -g @vishalgojha/social-cli" >&2
  exit 1
fi

# Defaults
MODE="${1:-daily-check}"
shift 2>/dev/null || true
ACCOUNT="${META_AD_ACCOUNT:-}"
PRESET="last_7d"
LIMIT=25
STATUS=""
CPA_THRESHOLD=""
LEVEL=""
FIELDS=""
BREAKDOWNS=""

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --account)    ACCOUNT="$2"; shift 2 ;;
    --preset)     PRESET="$2"; shift 2 ;;
    --limit)      LIMIT="$2"; shift 2 ;;
    --status)     STATUS="$2"; shift 2 ;;
    --cpa-threshold) CPA_THRESHOLD="$2"; shift 2 ;;
    --level)      LEVEL="$2"; shift 2 ;;
    --fields)     FIELDS="$2"; shift 2 ;;
    --breakdowns) BREAKDOWNS="$2"; shift 2 ;;
    *)            echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# Normalize account ID
normalize_act() {
  local act="$1"
  if [[ -n "$act" && ! "$act" =~ ^act_ ]]; then
    echo "act_${act}"
  else
    echo "$act"
  fi
}

ACCOUNT=$(normalize_act "$ACCOUNT")
ACCOUNT_ARG=""
[[ -n "$ACCOUNT" ]] && ACCOUNT_ARG="$ACCOUNT"

# Helper: run social command with --json and suppress banner
run_social() {
  social --no-banner "$@" --json 2>/dev/null
}

# Helper: run social command with table output
run_social_table() {
  social --no-banner "$@" --table 2>&1 | grep -v "^[/ _|\\]" | grep -v "token gymnastics" | grep -v "Chaos Craft"
}

fmt_num() { printf "%'d" "${1:-0}" 2>/dev/null || echo "${1:-0}"; }
fmt_money() { printf "$%'.2f" "${1:-0}" 2>/dev/null || echo "\$${1:-0}"; }
fmt_pct() { printf "%.1f%%" "${1:-0}" 2>/dev/null || echo "${1:-0}%"; }

# ============================================
# REPORT: daily-check (The 5 Daily Questions)
# ============================================
report_daily_check() {
  echo "═══════════════════════════════════════"
  echo "  META ADS — DAILY CHECK"
  echo "  The 5 Questions That Matter"
  [[ -n "$ACCOUNT" ]] && echo "  Account: $ACCOUNT"
  echo "═══════════════════════════════════════"
  echo ""

  # Q1: What's my spend vs yesterday?
  echo "① SPEND: Am I on track?"
  echo "---"
  social --no-banner marketing status $ACCOUNT_ARG 2>&1 | grep -v "^[/ _|\\]" | grep -v "token gymnastics" | grep -v "Chaos Craft" | grep -v "^$" || echo "  (Run 'social auth login' to connect)"
  echo ""

  # Q2: Which campaigns are active and what's their status?
  echo "② CAMPAIGNS: What's running?"
  echo "---"
  social --no-banner marketing campaigns $ACCOUNT_ARG --status ACTIVE --table 2>&1 | grep -v "^[/ _|\\]" | grep -v "token gymnastics" | grep -v "Chaos Craft" | head -20 || echo "  No active campaigns found"
  echo ""

  # Q3: What are the insights for last 7 days?
  echo "③ PERFORMANCE: Last 7 days"
  echo "---"
  social --no-banner marketing insights $ACCOUNT_ARG --preset last_7d --level campaign --table 2>&1 | grep -v "^[/ _|\\]" | grep -v "token gymnastics" | grep -v "Chaos Craft" | head -20 || echo "  No insights data"
  echo ""

  # Q4: Ad-level performance (find bleeders and winners)
  echo "④ AD PERFORMANCE: Winners & losers"
  echo "---"
  local tmpfile="/tmp/meta-ads-insights-$$.json"
  social --no-banner marketing insights $ACCOUNT_ARG --preset last_7d --level ad --json --fields "ad_name,spend,impressions,clicks,cpc,ctr,actions,cost_per_action_type" 2>/dev/null > "$tmpfile" || true

  if [[ -s "$tmpfile" ]]; then
    # Top spenders
    echo "  Top spending ads (last 7d):"
    jq -r '
      if type == "array" then
        sort_by(-.spend) | .[0:5][] |
        "  • \(.ad_name // "Unknown") — $\(.spend // 0) spend, \(.ctr // "?")% CTR, $\(.cpc // "?") CPC"
      elif .data then
        .data | sort_by(-.spend) | .[0:5][] |
        "  • \(.ad_name // "Unknown") — $\(.spend // 0) spend, \(.ctr // "?")% CTR, $\(.cpc // "?") CPC"
      else
        "  No ad-level data available"
      end
    ' "$tmpfile" 2>/dev/null || echo "  Parsing insights..."
    rm -f "$tmpfile"
  else
    echo "  No ad-level insights available"
  fi
  echo ""

  # Q5: Creative fatigue signals
  echo "⑤ CREATIVE: Any fatigue signals?"
  echo "---"
  echo "  Check daily breakdown for CTR decline over time:"
  social --no-banner marketing insights $ACCOUNT_ARG --preset last_7d --level ad --time-increment 1 --table --fields "ad_name,impressions,ctr,cpc,frequency" 2>&1 | grep -v "^[/ _|\\]" | grep -v "token gymnastics" | grep -v "Chaos Craft" | head -15 || echo "  No daily breakdown available"
  echo ""
  echo "  ↑ Watch for: CTR dropping day-over-day, frequency >3, CPC rising"
}

# ============================================
# REPORT: overview
# ============================================
report_overview() {
  echo "Meta Ads Overview — ${PRESET}"
  [[ -n "$ACCOUNT" ]] && echo "Account: $ACCOUNT"
  echo "================================"
  echo ""

  # Account status
  echo "Account Status:"
  run_social_table marketing status $ACCOUNT_ARG
  echo ""

  # Insights
  echo "Performance Summary:"
  run_social_table marketing insights $ACCOUNT_ARG --preset "$PRESET" --level account
  echo ""

  # Campaign breakdown
  echo "By Campaign:"
  run_social_table marketing insights $ACCOUNT_ARG --preset "$PRESET" --level campaign
}

# ============================================
# REPORT: campaigns
# ============================================
report_campaigns() {
  echo "Active Campaigns"
  [[ -n "$ACCOUNT" ]] && echo "Account: $ACCOUNT"
  echo "================================"
  echo ""

  local status_filter=""
  [[ -n "$STATUS" ]] && status_filter="--status $STATUS"

  run_social_table marketing campaigns $ACCOUNT_ARG $status_filter
}

# ============================================
# REPORT: top-creatives
# ============================================
report_top_creatives() {
  echo "Top Creatives — ${PRESET}"
  [[ -n "$ACCOUNT" ]] && echo "Account: $ACCOUNT"
  echo "================================"
  echo ""

  run_social_table marketing insights $ACCOUNT_ARG --preset "$PRESET" --level ad --fields "ad_name,spend,impressions,clicks,ctr,cpc,actions,cost_per_action_type"
}

# ============================================
# REPORT: bleeders (high spend, low performance)
# ============================================
report_bleeders() {
  echo "🩸 Potential Bleeders — ${PRESET}"
  [[ -n "$ACCOUNT" ]] && echo "Account: $ACCOUNT"
  echo "================================"
  echo ""
  echo "Ads with high spend and poor CTR/CPC (candidates for pause):"
  echo ""

  local tmpfile="/tmp/meta-ads-bleeders-$$.json"
  social --no-banner marketing insights $ACCOUNT_ARG --preset "$PRESET" --level ad --json --fields "ad_name,adset_name,campaign_name,spend,impressions,clicks,ctr,cpc,actions,cost_per_action_type,frequency" 2>/dev/null > "$tmpfile" || true

  if [[ -s "$tmpfile" ]]; then
    jq -r '
      def parse_num: if . == null then 0 elif type == "string" then (tonumber? // 0) else . end;
      (if type == "array" then . elif .data then .data else [] end) |
      map(select(.spend | parse_num > 0)) |
      sort_by(-(.spend | parse_num)) |
      .[] |
      select((.ctr | parse_num) < 1.0 or (.frequency | parse_num) > 3.5) |
      "⚠️  \(.ad_name // "Unknown")\n   Campaign: \(.campaign_name // "?")\n   Spend: $\(.spend) | CTR: \(.ctr)% | CPC: $\(.cpc) | Freq: \(.frequency)\n"
    ' "$tmpfile" 2>/dev/null || echo "No bleeders detected (or data format unexpected)"
    rm -f "$tmpfile"
  else
    echo "No insights data available"
  fi
}

# ============================================
# REPORT: winners (high ROAS / low CPA)
# ============================================
report_winners() {
  echo "🏆 Winners — ${PRESET}"
  [[ -n "$ACCOUNT" ]] && echo "Account: $ACCOUNT"
  echo "================================"
  echo ""
  echo "Top performing ads by CTR and efficiency:"
  echo ""

  local tmpfile="/tmp/meta-ads-winners-$$.json"
  social --no-banner marketing insights $ACCOUNT_ARG --preset "$PRESET" --level ad --json --fields "ad_name,adset_name,campaign_name,spend,impressions,clicks,ctr,cpc,actions,cost_per_action_type" 2>/dev/null > "$tmpfile" || true

  if [[ -s "$tmpfile" ]]; then
    jq -r '
      def parse_num: if . == null then 0 elif type == "string" then (tonumber? // 0) else . end;
      (if type == "array" then . elif .data then .data else [] end) |
      map(select(.spend | parse_num > 0)) |
      sort_by(-(.ctr | parse_num)) |
      .[0:10][] |
      "🏆 \(.ad_name // "Unknown")\n   Campaign: \(.campaign_name // "?")\n   Spend: $\(.spend) | CTR: \(.ctr)% | CPC: $\(.cpc) | Clicks: \(.clicks)\n"
    ' "$tmpfile" 2>/dev/null || echo "No data (or format unexpected)"
    rm -f "$tmpfile"
  else
    echo "No insights data available"
  fi
}

# ============================================
# REPORT: fatigue-check
# ============================================
report_fatigue_check() {
  echo "😴 Creative Fatigue Check — Last 7 days (daily)"
  [[ -n "$ACCOUNT" ]] && echo "Account: $ACCOUNT"
  echo "================================"
  echo ""
  echo "Watching for: frequency >3, CTR declining day-over-day, CPC rising"
  echo ""

  run_social_table marketing insights $ACCOUNT_ARG --preset last_7d --level ad --time-increment 1 --fields "ad_name,date_start,impressions,ctr,cpc,frequency"
}

# ============================================
# REPORT: custom
# ============================================
report_custom() {
  local args=()
  [[ -n "$ACCOUNT_ARG" ]] && args+=("$ACCOUNT_ARG")
  [[ -n "$PRESET" ]] && args+=(--preset "$PRESET")
  [[ -n "$LEVEL" ]] && args+=(--level "$LEVEL")
  [[ -n "$FIELDS" ]] && args+=(--fields "$FIELDS")
  [[ -n "$BREAKDOWNS" ]] && args+=(--breakdowns "$BREAKDOWNS")
  [[ -n "$LIMIT" ]] && args+=(--limit "$LIMIT")

  run_social_table marketing insights "${args[@]}"
}

# ============================================
# Dispatch
# ============================================
case "$MODE" in
  daily-check|daily|check|5questions) report_daily_check ;;
  overview)                           report_overview ;;
  campaigns)                          report_campaigns ;;
  top-creatives|creatives)            report_top_creatives ;;
  bleeders|losers)                    report_bleeders ;;
  winners|tops)                       report_winners ;;
  fatigue-check|fatigue)              report_fatigue_check ;;
  custom)                             report_custom ;;
  *)
    echo "Unknown mode: $MODE" >&2
    echo "Available: daily-check, overview, campaigns, top-creatives, bleeders, winners, fatigue-check, custom" >&2
    exit 1
    ;;
esac
