#!/usr/bin/env bash
# budget-optimizer.sh — Analyze spend efficiency and recommend budget shifts
#
# Usage:
#   budget-optimizer.sh efficiency [--account act_123] [--preset last_7d]
#   budget-optimizer.sh recommend [--account act_123]
#   budget-optimizer.sh pacing [--account act_123]

set -euo pipefail

if ! command -v social &>/dev/null; then
  echo "ERROR: social-cli not installed. Run: npm install -g @vishalgojha/social-cli" >&2
  exit 1
fi

MODE="${1:-efficiency}"
shift 2>/dev/null || true
ACCOUNT="${META_AD_ACCOUNT:-}"
PRESET="last_7d"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --account) ACCOUNT="$2"; shift 2 ;;
    --preset)  PRESET="$2"; shift 2 ;;
    *)         echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$ACCOUNT" && ! "$ACCOUNT" =~ ^act_ ]] && ACCOUNT="act_${ACCOUNT}"
ACCOUNT_ARG=""
[[ -n "$ACCOUNT" ]] && ACCOUNT_ARG="$ACCOUNT"

case "$MODE" in
  efficiency)
    echo "💰 Spend Efficiency Ranking — ${PRESET}"
    echo "========================================"
    echo ""

    tmpfile="/tmp/budget-opt-$$.json"
    social --no-banner marketing insights $ACCOUNT_ARG \
      --preset "$PRESET" --level campaign \
      --json --fields "campaign_name,campaign_id,spend,impressions,clicks,ctr,cpc,actions,cost_per_action_type" \
      2>/dev/null > "$tmpfile" || true

    if [[ -s "$tmpfile" ]]; then
      echo "Campaigns ranked by efficiency (CTR/CPC ratio):"
      echo ""
      jq -r '
        def parse_num: if . == null then 0 elif type == "string" then (tonumber? // 0) else . end;
        (if type == "array" then . elif .data then .data else [] end) |
        map(select(.spend | parse_num > 0)) |
        map(. + {efficiency: ((.ctr | parse_num) / (if (.cpc | parse_num) > 0 then (.cpc | parse_num) else 1 end))}) |
        sort_by(-.efficiency) |
        to_entries[] |
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
    social --no-banner marketing insights $ACCOUNT_ARG \
      --preset last_7d --level campaign \
      --json --fields "campaign_name,campaign_id,spend,ctr,cpc,actions,cost_per_action_type" \
      2>/dev/null > "$tmpfile" || true

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
          "\n\nUNDERPERFORERS (decrease budget):\n" +
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
    social --no-banner marketing status $ACCOUNT_ARG \
      2>&1 | grep -v "^[/ _|\\]" | grep -v "token gymnastics" | grep -v "Chaos Craft"
    echo ""
    echo "Campaign-level spend (today):"
    social --no-banner marketing insights $ACCOUNT_ARG \
      --preset today --level campaign --table \
      --fields "campaign_name,spend,impressions,clicks" \
      2>&1 | grep -v "^[/ _|\\]" | grep -v "token gymnastics" | grep -v "Chaos Craft"
    ;;

  *)
    echo "Unknown mode: $MODE" >&2
    echo "Available: efficiency, recommend, pacing" >&2
    exit 1
    ;;
esac
