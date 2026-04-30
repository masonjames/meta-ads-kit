#!/usr/bin/env bash
# creative-monitor.sh — Track creative performance and detect fatigue via meta-ads CLI
#
# Usage:
#   creative-monitor.sh fatigue-check
#   creative-monitor.sh weekly-report
#   creative-monitor.sh track-ad AD_ID

set -euo pipefail

META_ADS_BIN="${META_ADS_CLI:-meta-ads}"
if ! command -v "$META_ADS_BIN" &>/dev/null; then
  echo "ERROR: meta-ads CLI not found. Install it or set META_ADS_CLI=/path/to/meta-ads" >&2
  exit 1
fi

MODE="${1:-fatigue-check}"
shift 2>/dev/null || true
AD_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ad-id) AD_ID="$2"; shift 2 ;;
    *)       AD_ID="$1"; shift ;;
  esac
done

run_meta_json() {
  "$META_ADS_BIN" -o json "$@"
}

insights_json() {
  run_meta_json ads insights get "$@"
}

json_data_filter='if type == "array" then . elif .data then .data else [] end'

case "$MODE" in
  fatigue-check|fatigue)
    echo "😴 Creative Fatigue Scan"
    echo "========================"
    echo ""
    echo "Pulling 7-day daily breakdown for active ads..."
    echo ""

    tmpfile="/tmp/creative-monitor-$$.json"
    insights_json \
      --date-preset last_7d --time-increment daily \
      --fields "ad_name,ad_id,date_start,impressions,clicks,ctr,cpc,frequency,spend" \
      --sort spend_descending --limit 500 \
      > "$tmpfile" 2>/dev/null || true

    if [[ -s "$tmpfile" ]]; then
      echo "Day-over-day CTR trends:"
      echo ""
      jq -r '
        def parse_num: if . == null then 0 elif type == "string" then (tonumber? // 0) else . end;
        (if type == "array" then . elif .data then .data else [] end) |
        group_by(.ad_id) |
        .[]? |
        sort_by(.date_start) |
        . as $days |
        if length > 1 then
          ($days[0].ad_name // "Unknown") as $name |
          ($days[0].ad_id // "?") as $id |
          ($days | map(.ctr | parse_num)) as $ctrs |
          ($days | map(.frequency | parse_num)) as $freqs |
          (if ($ctrs | length) > 2 and ($ctrs[-1] < $ctrs[-3] * 0.8) then "🔴 FATIGUED"
           elif ($freqs[-1] > 3.5) then "🟡 HIGH FREQ"
           else "✅ OK" end) as $status |
          "\($status) \($name) (ID: \($id))\n  CTR trend: \($ctrs | map(tostring + "%") | join(" → "))\n  Freq: \($freqs[-1])\n"
        else empty end
      ' "$tmpfile" 2>/dev/null || echo "Could not parse daily data"
      rm -f "$tmpfile"
    else
      echo "No daily data available"
    fi
    ;;

  weekly-report|weekly)
    echo "📊 Weekly Creative Health Report"
    echo "================================="
    echo ""
    insights_json \
      --date-preset last_7d \
      --fields "ad_name,ad_id,campaign_name,campaign_id,spend,impressions,clicks,ctr,cpc,frequency" \
      --sort spend_descending --limit 100 | \
      jq -r "$json_data_filter | .[]? | \"  • \(.ad_name // \"Unknown\") — spend $\(.spend // 0), impressions \(.impressions // 0), clicks \(.clicks // 0), CTR \(.ctr // \"?\")%, CPC $\(.cpc // \"?\"), freq \(.frequency // \"?\")\"" 2>/dev/null \
      || echo "No creative data available"
    ;;

  track-ad|track)
    if [[ -z "$AD_ID" ]]; then
      echo "Usage: creative-monitor.sh track-ad AD_ID" >&2
      exit 1
    fi
    echo "📈 Tracking Ad: $AD_ID"
    echo "========================"
    echo ""
    insights_json \
      --date-preset last_14d --time-increment daily \
      --fields "ad_name,ad_id,date_start,impressions,clicks,ctr,cpc,frequency,spend" \
      --ad-id "$AD_ID" --limit 100 | \
      jq -r "$json_data_filter | .[]? | \"  • \(.date_start // \"?\") — \(.ad_name // \"Unknown\"): impressions \(.impressions // 0), clicks \(.clicks // 0), CTR \(.ctr // \"?\")%, CPC $\(.cpc // \"?\"), freq \(.frequency // \"?\"), spend $\(.spend // 0)\"" 2>/dev/null \
      || echo "No tracking data available"
    ;;

  *)
    echo "Unknown mode: $MODE" >&2
    echo "Available: fatigue-check, weekly-report, track-ad" >&2
    exit 1
    ;;
esac
