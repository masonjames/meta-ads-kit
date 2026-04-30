#!/usr/bin/env bash
# budget-optimizer.sh — Analyze spend efficiency and recommend budget shifts via meta-ads CLI
#
# Usage:
#   budget-optimizer.sh efficiency [--date-preset last_7d]
#   budget-optimizer.sh recommend
#   budget-optimizer.sh pacing

set -euo pipefail

META_ADS_BIN="${META_ADS_CLI:-meta-ads}"
if ! command -v "$META_ADS_BIN" &>/dev/null; then
  echo "ERROR: meta-ads CLI not found. Install it or set META_ADS_CLI=/path/to/meta-ads" >&2
  exit 1
fi

MODE="${1:-efficiency}"
shift 2>/dev/null || true
DATE_PRESET="last_7d"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --date-preset) DATE_PRESET="$2"; shift 2 ;;
    *)             echo "Unknown arg: $1" >&2; exit 1 ;;
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
  efficiency)
    echo "💰 Spend Efficiency Ranking — ${DATE_PRESET}"
    echo "========================================"
    echo ""

    tmpfile="/tmp/budget-opt-$$.json"
    insights_json \
      --date-preset "$DATE_PRESET" \
      --fields "campaign_name,campaign_id,spend,impressions,clicks,ctr,cpc,actions,cost_per_action_type" \
      --sort spend_descending --limit 100 \
      > "$tmpfile" 2>/dev/null || true

    if [[ -s "$tmpfile" ]]; then
      echo "Campaigns ranked by efficiency (CTR/CPC ratio):"
      echo ""
      jq -r '
        def parse_num: if . == null then 0 elif type == "string" then (tonumber? // 0) else . end;
        (if type == "array" then . elif .data then .data else [] end) |
        map(select(.spend | parse_num > 0)) |
        map(. + {efficiency: ((.ctr | parse_num) / (if (.cpc | parse_num) > 0 then (.cpc | parse_num) else 1 end))}) |
        sort_by(-.efficiency) |
        to_entries[]? |
        "#\(.key + 1) \(.value.campaign_name // "Unknown")\n   Spend: $\(.value.spend) | CTR: \(.value.ctr)% | CPC: $\(.value.cpc) | Score: \(.value.efficiency | . * 100 | floor / 100)\n"
      ' "$tmpfile" 2>/dev/null || echo "Could not parse campaign data"
      rm -f "$tmpfile"
    else
      echo "No campaign data available"
    fi
    ;;

  recommend)
    echo "💡 Budget Shift Recommendations"
    echo "================================"
    echo ""

    tmpfile="/tmp/budget-rec-$$.json"
    insights_json \
      --date-preset last_7d \
      --fields "campaign_name,campaign_id,spend,ctr,cpc,actions,cost_per_action_type" \
      --sort ctr_descending --limit 100 \
      > "$tmpfile" 2>/dev/null || true

    if [[ -s "$tmpfile" ]]; then
      jq -r '
        def parse_num: if . == null then 0 elif type == "string" then (tonumber? // 0) else . end;
        (if type == "array" then . elif .data then .data else [] end) |
        map(select(.spend | parse_num > 0)) |
        sort_by(-(.ctr | parse_num)) |
        . as $all |
        ($all | length) as $n |
        if $n < 2 then "Need at least 2 campaigns to compare"
        else
          "TOP PERFORMERS (increase budget):\n" +
          ($all[:($n / 3 | ceil)] | map("  🏆 \(.campaign_name) — CTR: \(.ctr)%, CPC: $\(.cpc)") | join("\n")) +
          "\n\nUNDERPERFORMERS (decrease budget):\n" +
          ($all[($n * 2 / 3 | floor):] | map("  🩸 \(.campaign_name) — CTR: \(.ctr)%, CPC: $\(.cpc)") | join("\n")) +
          "\n\n⚠️  These are recommendations only. Approve before I make changes."
        end
      ' "$tmpfile" 2>/dev/null || echo "Could not generate recommendations"
      rm -f "$tmpfile"
    else
      echo "No data for recommendations"
    fi
    ;;

  pacing)
    echo "📊 Spend Pacing Check"
    echo "======================"
    echo ""
    echo "Account spend today:"
    insights_json \
      --date-preset today \
      --fields "account_name,spend,impressions,clicks" \
      --limit 10 | \
      jq -r "$json_data_filter | .[]? | \"  • \(.account_name // \"Account\") — spend $\(.spend // 0), impressions \(.impressions // 0), clicks \(.clicks // 0)\"" 2>/dev/null \
      || echo "No account pacing data available"
    echo ""
    echo "Campaign-level spend (today):"
    insights_json \
      --date-preset today \
      --fields "campaign_name,campaign_id,spend,impressions,clicks" \
      --sort spend_descending --limit 100 | \
      jq -r "$json_data_filter | .[]? | \"  • \(.campaign_name // \"Unknown\") — spend $\(.spend // 0), impressions \(.impressions // 0), clicks \(.clicks // 0)\"" 2>/dev/null \
      || echo "No campaign pacing data available"
    ;;

  *)
    echo "Unknown mode: $MODE" >&2
    echo "Available: efficiency, recommend, pacing" >&2
    exit 1
    ;;
esac
