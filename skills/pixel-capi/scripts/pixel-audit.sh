#!/usr/bin/env bash
# pixel-audit.sh -- Audit Meta Pixel config, auto-matching fields, event stats, infer EMQ
#
# Usage:
#   pixel-audit.sh <account_id_or_pixel_id>
#
# If given an ad account ID (act_XXXXXX or just the number): lists all pixels, audits each
# If given a pixel ID directly (no act_ prefix, or a long numeric ID): audits that pixel only
#
# Requires: META_TOKEN env var or ~/.social-cli/config.json with meta_access_token

set -euo pipefail

API_BASE="https://graph.facebook.com/v19.0"

# ---- Token resolution ----
get_token() {
  if [[ -n "${META_TOKEN:-}" ]]; then
    echo "$META_TOKEN"
    return
  fi
  local config="$HOME/.social-cli/config.json"
  if [[ -f "$config" ]]; then
    local tok
    tok=$(jq -r '.meta_access_token // .access_token // empty' "$config" 2>/dev/null || true)
    if [[ -n "$tok" ]]; then
      echo "$tok"
      return
    fi
  fi
  echo "ERROR: META_TOKEN not set and not found in ~/.social-cli/config.json" >&2
  echo "Set it: export META_TOKEN=your_token" >&2
  exit 1
}

TOKEN=$(get_token)

# ---- Args ----
if [[ $# -lt 1 ]]; then
  echo "Usage: pixel-audit.sh <account_id_or_pixel_id>" >&2
  exit 1
fi

INPUT="$1"

# Normalize account ID
normalize_act() {
  local v="$1"
  if [[ "$v" =~ ^act_ ]]; then
    echo "$v"
  elif [[ "$v" =~ ^[0-9]+$ ]] && [[ ${#v} -lt 16 ]]; then
    # Short numeric -- likely account ID
    echo "act_${v}"
  else
    echo "$v"
  fi
}

INPUT_NORM=$(normalize_act "$INPUT")

# ---- EMQ estimation weights ----
# Returns estimated EMQ score based on configured matching fields
estimate_emq() {
  local fields_json="$1"
  local score=0

  # Base score -- IP + UA assumed always present in CAPI
  score=$(echo "$score + 1.5" | bc)

  # High value fields
  echo "$fields_json" | grep -q '"EMAIL"' && score=$(echo "$score + 2.5" | bc)
  echo "$fields_json" | grep -q '"PHONE"' && score=$(echo "$score + 2.0" | bc)

  # Medium value fields
  echo "$fields_json" | grep -q '"FIRST_NAME"' && score=$(echo "$score + 0.8" | bc)
  echo "$fields_json" | grep -q '"LAST_NAME"' && score=$(echo "$score + 0.8" | bc)

  # FBP/FBC -- medium (can't detect from auto_matching_fields, assume present if CAPI is set up)
  # We flag this separately

  # Geo fields
  echo "$fields_json" | grep -q '"CITY"' && score=$(echo "$score + 0.3" | bc)
  echo "$fields_json" | grep -q '"STATE"' && score=$(echo "$score + 0.3" | bc)
  echo "$fields_json" | grep -q '"ZIP"' && score=$(echo "$score + 0.3" | bc)
  echo "$fields_json" | grep -q '"COUNTRY"' && score=$(echo "$score + 0.2" | bc)

  # External ID
  echo "$fields_json" | grep -q '"EXTERNAL_ID"' && score=$(echo "$score + 0.5" | bc)

  # Cap at 9.9
  echo "$score" | awk '{if ($1 > 9.9) print "9.9"; else printf "%.1f\n", $1}'
}

# ---- Audit a single pixel ----
audit_pixel() {
  local pixel_id="$1"
  local pixel_name="${2:-$pixel_id}"

  echo ""
  echo "========================================"
  echo "PIXEL AUDIT: $pixel_name ($pixel_id)"
  echo "========================================"

  # Fetch pixel config
  local config
  config=$(curl -sf \
    "${API_BASE}/${pixel_id}?fields=name,automatic_matching_fields,first_party_cookie_status,data_use_setting,is_unavailable&access_token=${TOKEN}" \
    2>/dev/null || echo '{"error":"fetch_failed"}')

  if echo "$config" | grep -q '"error"'; then
    local err
    err=$(echo "$config" | jq -r '.error.message // .error // "Unknown error"' 2>/dev/null || echo "Unknown error")
    echo "  ERROR: Could not fetch pixel config -- $err"
    return 1
  fi

  local name
  name=$(echo "$config" | jq -r '.name // "Unknown"')
  local auto_fields
  auto_fields=$(echo "$config" | jq -c '.automatic_matching_fields // []')
  local cookie_status
  cookie_status=$(echo "$config" | jq -r '.first_party_cookie_status // "unknown"')
  local data_use
  data_use=$(echo "$config" | jq -r '.data_use_setting // "unknown"')

  echo ""
  echo "-- CONFIGURATION CHECKS --"

  # First-party cookies
  if [[ "$cookie_status" == "FIRST_PARTY_COOKIE_ENABLED" ]]; then
    echo "  [PASS] First-party cookies: ENABLED"
  else
    echo "  [WARN] First-party cookies: $cookie_status (should be ENABLED)"
  fi

  # Data use setting
  if [[ "$data_use" == "ADVERTISING_AND_ANALYTICS" || "$data_use" == "EMPTY_STRING" ]]; then
    echo "  [PASS] Data use setting: $data_use"
  else
    echo "  [WARN] Data use setting: $data_use"
  fi

  echo ""
  echo "-- AUTOMATIC MATCHING FIELDS --"
  local field_count
  field_count=$(echo "$auto_fields" | jq 'length')

  local has_email=false has_phone=false has_fn=false has_ln=false
  local has_city=false has_state=false has_zip=false has_country=false has_external=false

  echo "$auto_fields" | grep -q '"EMAIL"' && has_email=true
  echo "$auto_fields" | grep -q '"PHONE"' && has_phone=true
  echo "$auto_fields" | grep -q '"FIRST_NAME"' && has_fn=true
  echo "$auto_fields" | grep -q '"LAST_NAME"' && has_ln=true
  echo "$auto_fields" | grep -q '"CITY"' && has_city=true
  echo "$auto_fields" | grep -q '"STATE"' && has_state=true
  echo "$auto_fields" | grep -q '"ZIP"' && has_zip=true
  echo "$auto_fields" | grep -q '"COUNTRY"' && has_country=true
  echo "$auto_fields" | grep -q '"EXTERNAL_ID"' && has_external=true

  [[ "$has_email" == true ]]    && echo "  [PASS] Email (em) -- HIGH VALUE" || echo "  [FAIL] Email (em) -- MISSING (highest impact)"
  [[ "$has_phone" == true ]]    && echo "  [PASS] Phone (ph) -- HIGH VALUE" || echo "  [FAIL] Phone (ph) -- MISSING (high impact)"
  [[ "$has_fn" == true ]]       && echo "  [PASS] First name (fn)" || echo "  [WARN] First name (fn) -- missing (medium impact)"
  [[ "$has_ln" == true ]]       && echo "  [PASS] Last name (ln)" || echo "  [WARN] Last name (ln) -- missing (medium impact)"
  [[ "$has_city" == true ]]     && echo "  [PASS] City (ct)" || echo "  [INFO] City (ct) -- not configured"
  [[ "$has_state" == true ]]    && echo "  [PASS] State (st)" || echo "  [INFO] State (st) -- not configured"
  [[ "$has_zip" == true ]]      && echo "  [PASS] ZIP (zp)" || echo "  [INFO] ZIP (zp) -- not configured"
  [[ "$has_country" == true ]]  && echo "  [PASS] Country" || echo "  [INFO] Country -- not configured"
  [[ "$has_external" == true ]] && echo "  [PASS] External ID" || echo "  [INFO] External ID -- not configured (add CRM user ID for best results)"
  echo "  [INFO] FBP/FBC cookies -- cannot detect from API; verify CAPI passes these"
  echo "  [INFO] IP address + User agent -- verify your CAPI implementation passes these"

  # Fetch stats (last 24h)
  echo ""
  echo "-- EVENT STATS (last 24h) --"
  local stats
  stats=$(curl -sf \
    "${API_BASE}/${pixel_id}/stats?start_time=$(date -d '24 hours ago' +%s 2>/dev/null || date -v-24H +%s 2>/dev/null || echo $(($(date +%s) - 86400)))&aggregation=event&access_token=${TOKEN}" \
    2>/dev/null || echo '{"data":[]}')

  local event_count
  event_count=$(echo "$stats" | jq '.data | length' 2>/dev/null || echo 0)

  if [[ "$event_count" -eq 0 ]]; then
    echo "  [WARN] No events in last 24h -- pixel may not be firing, or no traffic"
  else
    echo "$stats" | jq -r '.data[] | "  [INFO] " + .event_name + ": " + (.count | tostring) + " events"' 2>/dev/null || \
    echo "  [INFO] Events detected but could not parse details"
  fi

  # EMQ estimate
  echo ""
  echo "-- EMQ ESTIMATE --"
  local emq
  emq=$(estimate_emq "$auto_fields")
  echo "  Estimated EMQ: $emq"
  echo ""
  echo "  Target: 9.3+ (Purchase), 8.0+ (Lead)"

  if (( $(echo "$emq >= 9.3" | bc -l) )); then
    echo "  [EXCELLENT] Your pixel is well-optimized"
  elif (( $(echo "$emq >= 8.0" | bc -l) )); then
    echo "  [GOOD] Strong signal -- room to improve"
  elif (( $(echo "$emq >= 6.0" | bc -l) )); then
    echo "  [NEEDS WORK] Significant signal loss -- see recommendations below"
  else
    echo "  [CRITICAL] Very low match quality -- campaigns are flying blind"
  fi

  echo ""
  echo "  ** IMPORTANT: This is an estimate based on configured matching fields."
  echo "     Actual EMQ depends on real event data passing these fields."
  echo "     Verify in: Events Manager > Data Sources > $pixel_name > Overview"

  # Recommendations
  echo ""
  echo "-- RECOMMENDATIONS (by impact) --"
  local recs=0

  if [[ "$has_email" == false ]]; then
    echo "  1. [HIGH] Enable email matching -- biggest EMQ gain. Enable in Pixel > Settings > Automatic Advanced Matching, or pass em in CAPI user_data."
    recs=$((recs+1))
  fi
  if [[ "$has_phone" == false ]]; then
    echo "  2. [HIGH] Enable phone matching -- second biggest gain. Add phone field to forms and pass ph in CAPI."
    recs=$((recs+1))
  fi
  if [[ "$has_fn" == false || "$has_ln" == false ]]; then
    echo "  3. [MEDIUM] Enable first + last name matching -- adds meaningful lift when combined with email/phone."
    recs=$((recs+1))
  fi
  echo "  4. [MEDIUM] Verify FBP + FBC cookies are passed in CAPI user_data -- cannot detect from API but critical for attribution."
  echo "  5. [MEDIUM] Verify client_ip_address and client_user_agent are passed in every CAPI event."
  if [[ "$has_external" == false ]]; then
    echo "  6. [LOW] Add external_id (your CRM/user ID, hashed) -- helps cross-device matching."
  fi
  if [[ "$cookie_status" != "FIRST_PARTY_COOKIE_ENABLED" ]]; then
    echo "  7. [MEDIUM] Enable first-party cookies in Pixel settings -- improves attribution in Safari/Firefox."
  fi

  echo ""
}

# ---- Main ----
if [[ "$INPUT_NORM" =~ ^act_ ]]; then
  # Account ID -- list all pixels
  echo "Fetching pixels for account: $INPUT_NORM"
  pixels=$(curl -sf \
    "${API_BASE}/${INPUT_NORM}/adspixels?fields=name,id,last_fired_time,is_capi_setup&access_token=${TOKEN}" \
    2>/dev/null || echo '{"error":"fetch_failed"}')

  if echo "$pixels" | grep -q '"error"'; then
    err=$(echo "$pixels" | jq -r '.error.message // .error // "Unknown error"' 2>/dev/null || echo "Unknown error")
    echo "ERROR: $err" >&2
    exit 1
  fi

  pixel_count=$(echo "$pixels" | jq '.data | length')
  echo "Found $pixel_count pixel(s)"

  echo "$pixels" | jq -c '.data[]' | while read -r px; do
    pid=$(echo "$px" | jq -r '.id')
    pname=$(echo "$px" | jq -r '.name // "Unnamed"')
    last_fired=$(echo "$px" | jq -r '.last_fired_time // "never"')
    capi_setup=$(echo "$px" | jq -r '.is_capi_setup // false')

    echo ""
    echo "Pixel: $pname ($pid) | Last fired: $last_fired | CAPI setup: $capi_setup"
    audit_pixel "$pid" "$pname"
  done
else
  # Direct pixel ID
  audit_pixel "$INPUT_NORM"
fi

echo ""
echo "========================================"
echo "Audit complete."
echo "Verify EMQ scores in Events Manager > Data Sources > [Pixel] > Overview"
echo "========================================"
