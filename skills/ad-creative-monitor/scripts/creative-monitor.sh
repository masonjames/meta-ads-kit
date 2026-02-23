#!/usr/bin/env bash
# creative-monitor.sh — Track creative performance and detect fatigue
#
# Usage:
#   creative-monitor.sh fatigue-check [--account act_123]
#   creative-monitor.sh weekly-report [--account act_123]
#   creative-monitor.sh track-ad AD_ID [--account act_123]

set -euo pipefail

if ! command -v social &>/dev/null; then
  echo "ERROR: social-cli not installed. Run: npm install -g @vishalgojha/social-cli" >&2
  exit 1
fi

MODE="${1:-fatigue-check}"
shift 2>/dev/null || true
ACCOUNT="${META_AD_ACCOUNT:-}"
AD_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --account) ACCOUNT="$2"; shift 2 ;;
    *)         AD_ID="$1"; shift ;;
  esac
done

[[ -n "$ACCOUNT" && ! "$ACCOUNT" =~ ^act_ ]] && ACCOUNT="act_${ACCOUNT}"
ACCOUNT_ARG=""
[[ -n "$ACCOUNT" ]] && ACCOUNT_ARG="$ACCOUNT"

case "$MODE" in
  fatigue-check|fatigue)
    echo "😴 Creative Fatigue Scan"
    echo "========================"
    echo ""
    echo "Pulling 7-day daily breakdown for all active ads..."
    echo ""

    tmpfile="/tmp/creative-monitor-$$.json"
    social --no-banner marketing insights $ACCOUNT_ARG \
      --preset last_7d --level ad --time-increment 1 \
      --json --fields "ad_name,ad_id,date_start,impressions,clicks,ctr,cpc,frequency,spend" \
      2>/dev/null > "$tmpfile" || true

    if [[ -s "$tmpfile" ]]; then
      echo "Day-over-day CTR trends:"
      echo ""
      jq -r '
        def parse_num: if . == null then 0 elif type == "string" then (tonumber? // 0) else . end;
        (if type == "array" then . elif .data then .data else [] end) |
        group_by(.ad_id) |
        .[] |
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
    social --no-banner marketing insights $ACCOUNT_ARG \
      --preset last_7d --level ad --table \
      --fields "ad_name,spend,impressions,clicks,ctr,cpc,frequency" \
      2>&1 | grep -v "^[/ _|\\]" | grep -v "token gymnastics" | grep -v "Chaos Craft"
    ;;

  track-ad|track)
    if [[ -z "$AD_ID" ]]; then
      echo "Usage: creative-monitor.sh track-ad AD_ID" >&2
      exit 1
    fi
    echo "📈 Tracking Ad: $AD_ID"
    echo "========================"
    echo ""
    social --no-banner marketing insights $ACCOUNT_ARG \
      --preset last_14d --level ad --time-increment 1 --table \
      --fields "ad_name,date_start,impressions,clicks,ctr,cpc,frequency,spend" \
      --filtering "[{\"field\":\"ad.id\",\"operator\":\"EQUAL\",\"value\":\"$AD_ID\"}]" \
      2>&1 | grep -v "^[/ _|\\]" | grep -v "token gymnastics" | grep -v "Chaos Craft"
    ;;

  *)
    echo "Unknown mode: $MODE" >&2
    echo "Available: fatigue-check, weekly-report, track-ad" >&2
    exit 1
    ;;
esac
