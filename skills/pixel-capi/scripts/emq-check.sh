#!/usr/bin/env bash
# emq-check.sh -- Analyze Meta Pixel matching params, estimate EMQ, recommend fixes
#
# Usage:
#   emq-check.sh <pixel_id>
#
# Pulls pixel config for automatic matching fields, scores each parameter,
# outputs weighted EMQ estimate and prioritized recommendations.
#
# NOTE: EMQ score is an ESTIMATE. Actual score depends on real event data.
# Verify in: Events Manager > Data Sources > [Pixel] > Overview
#
# Requires: META_TOKEN env var or ~/.social-cli/config.json with meta_access_token

set -euo pipefail

API_BASE="https://graph.facebook.com/v19.0"

get_token() {
  if [[ -n "${META_TOKEN:-}" ]]; then
    echo "$META_TOKEN"
    return
  fi
  local config="$HOME/.social-cli/config.json"
  if [[ -f "$config" ]]; then
    local tok
    tok=$(jq -r '.meta_access_token // .access_token // empty' "$config" 2>/dev/null || true)
    [[ -n "$tok" ]] && echo "$tok" && return
  fi
  echo "ERROR: META_TOKEN not set and not found in ~/.social-cli/config.json" >&2
  echo "Set it: export META_TOKEN=your_token" >&2
  exit 1
}

if [[ $# -lt 1 ]]; then
  echo "Usage: emq-check.sh <pixel_id>" >&2
  exit 1
fi

PIXEL_ID="$1"
TOKEN=$(get_token)

echo ""
echo "========================================"
echo "EMQ ANALYSIS"
echo "Pixel: $PIXEL_ID"
echo "========================================"

# ---- Fetch pixel config ----
echo ""
echo "Fetching pixel configuration..."

CONFIG=$(curl -sf \
  "${API_BASE}/${PIXEL_ID}?fields=name,automatic_matching_fields,first_party_cookie_status,data_use_setting,is_capi_setup&access_token=${TOKEN}" \
  2>/dev/null || echo '{"error":"fetch_failed"}')

if echo "$CONFIG" | grep -q '"error"'; then
  ERR=$(echo "$CONFIG" | jq -r '.error.message // .error // "Unknown error"' 2>/dev/null || echo "Unknown error")
  echo "ERROR: $ERR" >&2
  exit 1
fi

PIXEL_NAME=$(echo "$CONFIG" | jq -r '.name // "Unknown"')
AUTO_FIELDS=$(echo "$CONFIG" | jq -c '.automatic_matching_fields // []')
COOKIE_STATUS=$(echo "$CONFIG" | jq -r '.first_party_cookie_status // "unknown"')
IS_CAPI=$(echo "$CONFIG" | jq -r '.is_capi_setup // false')

echo "  Pixel: $PIXEL_NAME"
echo "  First-party cookies: $COOKIE_STATUS"
echo "  CAPI configured: $IS_CAPI"

# ---- Fetch recent event stats ----
echo ""
echo "Fetching event stats (last 24h)..."

SINCE=$(($(date +%s) - 86400))
STATS=$(curl -sf \
  "${API_BASE}/${PIXEL_ID}/stats?start_time=${SINCE}&aggregation=event&access_token=${TOKEN}" \
  2>/dev/null || echo '{"data":[]}')

EVENT_COUNT=$(echo "$STATS" | jq '.data | length' 2>/dev/null || echo 0)

# ---- Score matching parameters ----
echo ""
echo "========================================"
echo "MATCHING PARAMETER SCORECARD"
echo "========================================"
echo ""
echo "  Weight | Field           | Status        | Notes"
echo "  -------|-----------------|---------------|----------------------------------"

SCORE=0
MAX_POSSIBLE=10.0

# Check each field and score
check_field() {
  local field_key="$1"   # API field name (e.g., EMAIL)
  local display="$2"     # Display name
  local capi_key="$3"    # CAPI user_data key
  local weight="$4"      # Contribution to EMQ
  local impact="$5"      # Impact level for recommendations

  local present=false
  echo "$AUTO_FIELDS" | grep -q "\"${field_key}\"" && present=true

  local status icon
  if [[ "$present" == true ]]; then
    status="ENABLED"
    icon="[+]"
    SCORE=$(echo "$SCORE + $weight" | bc)
  else
    status="missing"
    icon="[ ]"
  fi

  printf "  %6s | %-15s | %-13s | %s\n" \
    "$weight" \
    "$display ($capi_key)" \
    "$status" \
    "$impact impact"
}

# Check auto-detectable fields
check_field "EMAIL"       "Email"       "em"          "2.5"  "HIGHEST"
check_field "PHONE"       "Phone"       "ph"          "2.0"  "HIGH"
check_field "FIRST_NAME"  "First Name"  "fn"          "0.8"  "MEDIUM"
check_field "LAST_NAME"   "Last Name"   "ln"          "0.8"  "MEDIUM"
check_field "CITY"        "City"        "ct"          "0.3"  "LOW"
check_field "STATE"       "State"       "st"          "0.3"  "LOW"
check_field "ZIP"         "ZIP"         "zp"          "0.3"  "LOW"
check_field "COUNTRY"     "Country"     "country"     "0.2"  "LOW"
check_field "EXTERNAL_ID" "External ID" "external_id" "0.5"  "MEDIUM"

# Base score for IP + UA (assumed present if CAPI is sending)
echo "  ------ | --------------- | ------------- | ----------------------------------"
if [[ "$IS_CAPI" == "true" ]]; then
  printf "  %6s | %-15s | %-13s | %s\n" "0.8" "IP Address (ip)" "assumed" "required for CAPI"
  printf "  %6s | %-15s | %-13s | %s\n" "0.7" "User Agent (ua)" "assumed" "required for CAPI"
  SCORE=$(echo "$SCORE + 1.5" | bc)
  FBP_FBC_NOTE="Note: FBP/FBC cannot be detected from API -- verify manually"
else
  printf "  %6s | %-15s | %-13s | %s\n" "0.8" "IP Address (ip)" "unverified" "CAPI not confirmed active"
  printf "  %6s | %-15s | %-13s | %s\n" "0.7" "User Agent (ua)" "unverified" "CAPI not confirmed active"
  FBP_FBC_NOTE="Note: Enable CAPI first, then IP+UA will contribute"
fi

printf "  %6s | %-15s | %-13s | %s\n" "0.6" "FBP Cookie (fbp)" "unverified" "Cannot detect from API -- verify in CAPI code"
printf "  %6s | %-15s | %-13s | %s\n" "0.5" "FBC Cookie (fbc)" "unverified" "Cannot detect from API -- verify in CAPI code"
echo ""
echo "  $FBP_FBC_NOTE"

# Adjust score for FBP/FBC estimate (assume 50% chance present if CAPI is active)
if [[ "$IS_CAPI" == "true" ]]; then
  SCORE=$(echo "$SCORE + 0.5" | bc)  # Conservative estimate for fbp/fbc
fi

# ---- EMQ estimate ----
echo ""
echo "========================================"
echo "EMQ ESTIMATE"
echo "========================================"

EMQ=$(echo "$SCORE" | awk '{if ($1 > 9.9) print "9.9"; else printf "%.1f\n", $1}')

echo ""
echo "  Estimated EMQ: $EMQ / 10.0"
echo ""

# Target assessment
if (( $(echo "$EMQ >= 9.3" | bc -l) )); then
  echo "  Status: EXCELLENT -- Hitting 9.3+ target"
  echo "  Your pixel is capturing strong signal. Maintain current setup."
elif (( $(echo "$EMQ >= 8.0" | bc -l) )); then
  echo "  Status: GOOD -- Room for improvement to reach 9.3+"
  echo "  Purchase target: 9.3+ | Lead target: 8.0+ (Lead: ACHIEVED)"
elif (( $(echo "$EMQ >= 6.0" | bc -l) )); then
  echo "  Status: NEEDS WORK -- Significant signal gap"
  echo "  Below both targets. Campaigns are under-optimized."
else
  echo "  Status: CRITICAL -- Very low match quality"
  echo "  Ad delivery algorithms are working with poor data. Fix immediately."
fi

echo ""
echo "  ** IMPORTANT: This is an ESTIMATE based on configured fields."
echo "     Real EMQ reflects actual event data passing these params."
echo "     Verify at: Events Manager > Data Sources > $PIXEL_NAME > Overview"

# ---- Recent event volume ----
echo ""
echo "========================================"
echo "EVENT VOLUME (last 24h)"
echo "========================================"

if [[ "$EVENT_COUNT" -eq 0 ]]; then
  echo "  [WARN] No events detected in last 24h"
  echo "  - Pixel may not be installed correctly"
  echo "  - Site may have no traffic"
  echo "  - Or stats API returned empty (low volume can show as 0)"
else
  echo ""
  echo "$STATS" | jq -r '.data[] | "  " + .event_name + ": " + (.count | tostring) + " events"' 2>/dev/null || \
    echo "  Events detected: $EVENT_COUNT event types"
fi

# ---- Prioritized recommendations ----
echo ""
echo "========================================"
echo "RECOMMENDATIONS (highest impact first)"
echo "========================================"
echo ""

REC_NUM=1

# Check email
if ! echo "$AUTO_FIELDS" | grep -q '"EMAIL"'; then
  echo "  $REC_NUM. [CRITICAL -- +2.5 EMQ] Add email matching"
  echo "     - Enable in: Events Manager > [Pixel] > Settings > Advanced Matching"
  echo "     - Also pass em (sha256 hashed email) in every CAPI call"
  echo "     - Collect email at checkout, lead forms, account creation"
  REC_NUM=$((REC_NUM+1))
fi

# Check phone
if ! echo "$AUTO_FIELDS" | grep -q '"PHONE"'; then
  echo "  $REC_NUM. [HIGH -- +2.0 EMQ] Add phone matching"
  echo "     - Add phone number field to forms where appropriate"
  echo "     - Hash format: digits only with country code (e.g., 15551234567)"
  echo "     - Enable automatic matching and pass ph in CAPI"
  REC_NUM=$((REC_NUM+1))
fi

# CAPI check
if [[ "$IS_CAPI" != "true" ]]; then
  echo "  $REC_NUM. [HIGH -- enables server-side] Set up CAPI"
  echo "     - CAPI is not confirmed active for this pixel"
  echo "     - Run: capi-test.sh $PIXEL_ID to test CAPI connectivity"
  echo "     - Without CAPI: iOS/ad blocker traffic = zero signal"
  REC_NUM=$((REC_NUM+1))
fi

# Cookie check
if [[ "$COOKIE_STATUS" != "FIRST_PARTY_COOKIE_ENABLED" ]]; then
  echo "  $REC_NUM. [MEDIUM] Enable first-party cookies"
  echo "     - Go to: Events Manager > [Pixel] > Settings"
  echo "     - Enable 'Use First Party Cookies'"
  echo "     - Improves attribution in Safari, Firefox, Brave"
  REC_NUM=$((REC_NUM+1))
fi

# FBP/FBC
echo "  $REC_NUM. [MEDIUM] Verify FBP + FBC are passed in CAPI"
echo "     - Read _fbp and _fbc cookies client-side"
echo "     - Pass both to your server with every event"
echo "     - Generate fbc from fbclid URL param when present"
echo "     - Format: fb.1.[timestamp].[fbclid_value]"
REC_NUM=$((REC_NUM+1))

# Name fields
if ! echo "$AUTO_FIELDS" | grep -q '"FIRST_NAME"' || ! echo "$AUTO_FIELDS" | grep -q '"LAST_NAME"'; then
  echo "  $REC_NUM. [MEDIUM -- +1.6 EMQ combined] Add first + last name"
  echo "     - Enable automatic matching in pixel settings"
  echo "     - Pass fn and ln (sha256 hashed, lowercase) in CAPI"
  REC_NUM=$((REC_NUM+1))
fi

# External ID
if ! echo "$AUTO_FIELDS" | grep -q '"EXTERNAL_ID"'; then
  echo "  $REC_NUM. [MEDIUM -- +0.5 EMQ] Add external_id"
  echo "     - Pass your CRM or database user ID (hashed) as external_id"
  echo "     - Enables cross-device matching for known users"
  REC_NUM=$((REC_NUM+1))
fi

# Geo fields
if ! echo "$AUTO_FIELDS" | grep -q '"CITY"' && \
   ! echo "$AUTO_FIELDS" | grep -q '"STATE"' && \
   ! echo "$AUTO_FIELDS" | grep -q '"ZIP"'; then
  echo "  $REC_NUM. [LOW -- +0.8 EMQ combined] Add geographic fields"
  echo "     - Pass ct (city), st (state), zp (zip), country in CAPI"
  echo "     - All hashed: lowercase, sha256"
fi

echo ""
echo "========================================"
echo "VERIFICATION"
echo "========================================"
echo ""
echo "  1. After making changes, run: emq-check.sh $PIXEL_ID"
echo "  2. Send test events: capi-test.sh $PIXEL_ID"
echo "  3. View actual EMQ: Events Manager > Data Sources > $PIXEL_NAME > Overview"
echo "  4. EMQ updates in Events Manager take 24-72h after changes"
echo ""
echo "Target: 9.3+ on Purchase | 8.0+ on Lead"
echo "========================================"
