#!/usr/bin/env bash
# meta-ads.sh — Pull Meta Ads data via the installed meta-ads CLI
#
# Usage:
#   meta-ads.sh daily-check
#   meta-ads.sh overview [--date-preset last_7d]
#   meta-ads.sh campaigns [--status ACTIVE]
#   meta-ads.sh top-creatives [--date-preset last_7d] [--limit 10]
#   meta-ads.sh bleeders [--date-preset last_7d] [--cpa-threshold 50]
#   meta-ads.sh winners [--date-preset last_7d]
#   meta-ads.sh fatigue-check
#   meta-ads.sh custom [--fields ...] [--breakdown age --breakdown gender] [--campaign-id ...] [--adset-id ...] [--ad-id ...]

set -euo pipefail

META_ADS_BIN="${META_ADS_CLI:-meta-ads}"
if ! command -v "$META_ADS_BIN" &>/dev/null; then
  echo "ERROR: meta-ads CLI not found. Install it or set META_ADS_CLI=/path/to/meta-ads" >&2
  exit 1
fi

MODE="${1:-daily-check}"
shift 2>/dev/null || true
DATE_PRESET="last_7d"
LIMIT=25
STATUS=""
CPA_THRESHOLD=""
FIELDS=""
SORT=""
SINCE=""
UNTIL=""
CAMPAIGN_ID=""
ADSET_ID=""
AD_ID=""
BREAKDOWNS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --date-preset) DATE_PRESET="$2"; shift 2 ;;
    --limit)       LIMIT="$2"; shift 2 ;;
    --status)      STATUS="$2"; shift 2 ;;
    --cpa-threshold) CPA_THRESHOLD="$2"; shift 2 ;;
    --fields)      FIELDS="$2"; shift 2 ;;
    --sort)        SORT="$2"; shift 2 ;;
    --since)       SINCE="$2"; shift 2 ;;
    --until)       UNTIL="$2"; shift 2 ;;
    --campaign-id) CAMPAIGN_ID="$2"; shift 2 ;;
    --adset-id)    ADSET_ID="$2"; shift 2 ;;
    --ad-id)       AD_ID="$2"; shift 2 ;;
    --breakdown)   BREAKDOWNS+=("$2"); shift 2 ;;
    *)             echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

run_meta_json() {
  "$META_ADS_BIN" -o json "$@"
}

insights_json() {
  local fields="$1"
  shift
  local args=(ads insights get --fields "$fields")

  if [[ -n "$SINCE" || -n "$UNTIL" ]]; then
    [[ -n "$SINCE" ]] && args+=(--since "$SINCE")
    [[ -n "$UNTIL" ]] && args+=(--until "$UNTIL")
  else
    args+=(--date-preset "$DATE_PRESET")
  fi

  [[ -n "$SORT" ]] && args+=(--sort "$SORT")
  [[ -n "$LIMIT" ]] && args+=(--limit "$LIMIT")
  [[ -n "$CAMPAIGN_ID" ]] && args+=(--campaign-id "$CAMPAIGN_ID")
  [[ -n "$ADSET_ID" ]] && args+=(--adset-id "$ADSET_ID")
  [[ -n "$AD_ID" ]] && args+=(--ad-id "$AD_ID")
  if (( ${#BREAKDOWNS[@]} > 0 )); then
    for breakdown in "${BREAKDOWNS[@]}"; do
      args+=(--breakdown "$breakdown")
    done
  fi

  run_meta_json "${args[@]}" "$@"
}

insights_daily_json() {
  local fields="$1"
  shift
  insights_json "$fields" --time-increment daily "$@"
}

json_data_filter='if type == "array" then . elif .data then .data else [] end'

print_campaign_summary() {
  jq -r "$json_data_filter | .[0:20][]? | \"  • \(.name // .campaign_name // \"Unknown\") — \(.status // .effective_status // \"status unknown\")\"" 2>/dev/null \
    || echo "  No campaign data available"
}

print_insights_rows() {
  jq -r "$json_data_filter | .[0:20][]? | \"  • \(.campaign_name // .ad_name // .account_name // \"Unknown\") — spend $\(.spend // 0), impressions \(.impressions // 0), clicks \(.clicks // 0), CTR \(.ctr // \"?\")%, CPC $\(.cpc // \"?\")\"" 2>/dev/null \
    || echo "  No insights data available"
}

report_daily_check() {
  echo "═══════════════════════════════════════"
  echo "  META ADS — DAILY CHECK"
  echo "  The 5 Questions That Matter"
  echo "═══════════════════════════════════════"
  echo ""

  echo "① SPEND: Am I on track?"
  echo "---"
  local saved_preset="$DATE_PRESET"
  DATE_PRESET="today"
  insights_json "account_name,spend,impressions,clicks,ctr,cpc" | print_insights_rows || echo "  (Run 'meta-ads auth status' and check ACCESS_TOKEN/AD_ACCOUNT_ID)"
  DATE_PRESET="$saved_preset"
  echo ""

  echo "② CAMPAIGNS: What's running?"
  echo "---"
  campaign_args=(ads campaign list)
  run_meta_json "${campaign_args[@]}" | print_campaign_summary || echo "  No campaigns found"
  echo ""

  echo "③ PERFORMANCE: Last 7 days"
  echo "---"
  DATE_PRESET="last_7d"
  insights_json "campaign_name,campaign_id,spend,impressions,clicks,ctr,cpc" | print_insights_rows || echo "  No insights data"
  DATE_PRESET="$saved_preset"
  echo ""

  echo "④ AD PERFORMANCE: Winners & losers"
  echo "---"
  local tmpfile="/tmp/meta-ads-insights-$$.json"
  DATE_PRESET="last_7d"
  SORT="spend_descending"
  LIMIT=10
  insights_json "ad_name,ad_id,campaign_name,campaign_id,spend,impressions,clicks,cpc,ctr,actions,cost_per_action_type" > "$tmpfile" 2>/dev/null || true
  SORT=""
  LIMIT=25
  DATE_PRESET="$saved_preset"

  if [[ -s "$tmpfile" ]]; then
    echo "  Top spending ads (last 7d):"
    jq -r '
      def parse_num: if . == null then 0 elif type == "string" then (tonumber? // 0) else . end;
      (if type == "array" then . elif .data then .data else [] end) |
      sort_by(-(.spend | parse_num)) | .[0:5][]? |
      "  • \(.ad_name // "Unknown") — $\(.spend // 0) spend, \(.ctr // "?")% CTR, $\(.cpc // "?") CPC"
    ' "$tmpfile" 2>/dev/null || echo "  Parsing insights failed"
    rm -f "$tmpfile"
  else
    echo "  No ad-level insights available"
  fi
  echo ""

  echo "⑤ CREATIVE: Any fatigue signals?"
  echo "---"
  echo "  Daily ad breakdown (watch CTR decline, frequency >3.5, CPC rising):"
  DATE_PRESET="last_7d"
  LIMIT=15
  insights_daily_json "ad_name,ad_id,date_start,impressions,ctr,cpc,frequency" | \
    jq -r "$json_data_filter | .[0:15][]? | \"  • \(.date_start // \"?\") — \(.ad_name // \"Unknown\"): CTR \(.ctr // \"?\")%, CPC $\(.cpc // \"?\"), freq \(.frequency // \"?\")\"" 2>/dev/null \
    || echo "  No daily breakdown available"
  LIMIT=25
  DATE_PRESET="$saved_preset"
  echo ""
  echo "  ↑ Watch for: CTR dropping day-over-day, frequency >3.5, CPC rising"
}

report_overview() {
  echo "Meta Ads Overview — ${DATE_PRESET}"
  echo "================================"
  echo ""

  echo "Account Performance:"
  insights_json "account_name,spend,impressions,clicks,ctr,cpc" | print_insights_rows
  echo ""

  echo "Campaign Rows:"
  insights_json "campaign_name,campaign_id,spend,impressions,clicks,ctr,cpc,actions,cost_per_action_type" | print_insights_rows
}

report_campaigns() {
  echo "Campaigns"
  echo "================================"
  echo ""

  local args=(ads campaign list)
  if [[ -n "$STATUS" ]]; then
    run_meta_json "${args[@]}" | jq --arg status "$STATUS" '
      (if type == "array" then . elif .data then .data else [] end)
      | map(select(((.status // .effective_status // "") | ascii_upcase) == ($status | ascii_upcase)))
    ' | print_campaign_summary
  else
    run_meta_json "${args[@]}" | print_campaign_summary
  fi
}

report_top_creatives() {
  echo "Top Creatives — ${DATE_PRESET}"
  echo "================================"
  echo ""

  [[ -z "$SORT" ]] && SORT="ctr_descending"
  insights_json "ad_name,ad_id,campaign_name,campaign_id,spend,impressions,clicks,ctr,cpc,actions,cost_per_action_type" | \
    jq -r '
      def parse_num: if . == null then 0 elif type == "string" then (tonumber? // 0) else . end;
      (if type == "array" then . elif .data then .data else [] end) |
      sort_by(-(.ctr | parse_num)) | .[0:20][]? |
      "  • \(.ad_name // "Unknown") — spend $\(.spend // 0), CTR \(.ctr // "?")%, CPC $\(.cpc // "?"), clicks \(.clicks // 0)"
    ' 2>/dev/null || echo "No creative data available"
}

report_bleeders() {
  echo "🩸 Potential Bleeders — ${DATE_PRESET}"
  echo "================================"
  echo ""
  echo "Ads with high spend and poor CTR/frequency (candidates for pause):"
  echo ""

  local tmpfile="/tmp/meta-ads-bleeders-$$.json"
  [[ -z "$SORT" ]] && SORT="spend_descending"
  insights_json "ad_name,ad_id,adset_name,adset_id,campaign_name,campaign_id,spend,impressions,clicks,ctr,cpc,actions,cost_per_action_type,frequency" > "$tmpfile" 2>/dev/null || true

  if [[ -s "$tmpfile" ]]; then
    jq -r '
      def parse_num: if . == null then 0 elif type == "string" then (tonumber? // 0) else . end;
      (if type == "array" then . elif .data then .data else [] end) |
      map(select(.spend | parse_num > 0)) |
      sort_by(-(.spend | parse_num)) |
      .[]? |
      select((.ctr | parse_num) < 1.0 or (.frequency | parse_num) > 3.5) |
      "⚠️  \(.ad_name // "Unknown")\n   Campaign: \(.campaign_name // "?")\n   Spend: $\(.spend) | CTR: \(.ctr)% | CPC: $\(.cpc) | Freq: \(.frequency)\n"
    ' "$tmpfile" 2>/dev/null || echo "No bleeders detected (or data format unexpected)"
    rm -f "$tmpfile"
  else
    echo "No insights data available"
  fi
}

report_winners() {
  echo "🏆 Winners — ${DATE_PRESET}"
  echo "================================"
  echo ""
  echo "Top performing ads by CTR and efficiency:"
  echo ""

  local tmpfile="/tmp/meta-ads-winners-$$.json"
  [[ -z "$SORT" ]] && SORT="ctr_descending"
  insights_json "ad_name,ad_id,adset_name,adset_id,campaign_name,campaign_id,spend,impressions,clicks,ctr,cpc,actions,cost_per_action_type" > "$tmpfile" 2>/dev/null || true

  if [[ -s "$tmpfile" ]]; then
    jq -r '
      def parse_num: if . == null then 0 elif type == "string" then (tonumber? // 0) else . end;
      (if type == "array" then . elif .data then .data else [] end) |
      map(select(.spend | parse_num > 0)) |
      sort_by(-(.ctr | parse_num)) |
      .[0:10][]? |
      "🏆 \(.ad_name // "Unknown")\n   Campaign: \(.campaign_name // "?")\n   Spend: $\(.spend) | CTR: \(.ctr)% | CPC: $\(.cpc) | Clicks: \(.clicks)\n"
    ' "$tmpfile" 2>/dev/null || echo "No data (or format unexpected)"
    rm -f "$tmpfile"
  else
    echo "No insights data available"
  fi
}

report_fatigue_check() {
  echo "😴 Creative Fatigue Check — Last 7 days (daily)"
  echo "================================"
  echo ""
  echo "Watching for: frequency >3.5, CTR declining day-over-day, CPC rising"
  echo ""

  local saved_preset="$DATE_PRESET"
  DATE_PRESET="last_7d"
  insights_daily_json "ad_name,ad_id,date_start,impressions,ctr,cpc,frequency" | \
    jq -r "$json_data_filter | .[]? | \"  • \(.date_start // \"?\") — \(.ad_name // \"Unknown\"): impressions \(.impressions // 0), CTR \(.ctr // \"?\")%, CPC $\(.cpc // \"?\"), freq \(.frequency // \"?\")\"" 2>/dev/null \
    || echo "No daily ad data available"
  DATE_PRESET="$saved_preset"
}

report_custom() {
  [[ -z "$FIELDS" ]] && FIELDS="campaign_name,campaign_id,ad_name,ad_id,spend,impressions,clicks,ctr,cpc"
  insights_json "$FIELDS" | jq .
}

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
