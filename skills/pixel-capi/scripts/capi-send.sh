#!/usr/bin/env bash
# capi-send.sh -- Send a real CAPI event with hashed user_data
#
# Usage:
#   capi-send.sh <pixel_id> <event_name> [options]
#
# Options:
#   --email "user@example.com"
#   --phone "15551234567"           (digits only, with country code)
#   --first-name "John"
#   --last-name "Doe"
#   --city "new york"
#   --state "ny"                    (2-letter code)
#   --zip "10001"
#   --country "us"                  (2-letter ISO)
#   --external-id "crm_user_123"    (your internal user ID)
#   --value 109.97
#   --currency USD
#   --url "https://site.com/thank-you"
#   --event-id "unique_dedup_id"    (auto-generated UUID if omitted)
#   --ip "203.0.113.1"
#   --ua "Mozilla/5.0..."
#   --fbp "fb.1.1234567890.987654321"
#   --fbc "fb.1.1234567890.IwAR..."
#   --test-code "TEST12345"         (if set, event goes to Test Events only)
#   --content-ids "SKU1,SKU2"
#   --num-items 1
#   --dry-run                       (print payload without sending)
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

hash_value() {
  local val="$1"
  # Lowercase, trim whitespace, then SHA-256
  echo -n "$(echo "$val" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')" | \
    sha256sum | cut -d' ' -f1
}

hash_phone() {
  local val="$1"
  # Remove non-digits, then hash
  local digits
  digits=$(echo "$val" | tr -dc '0-9')
  echo -n "$digits" | sha256sum | cut -d' ' -f1
}

gen_event_id() {
  # Generate unique event ID
  echo "evt_$(date +%s)_$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 10 2>/dev/null || date +%N | tail -c 10)"
}

# ---- Args ----
if [[ $# -lt 2 ]]; then
  echo "Usage: capi-send.sh <pixel_id> <event_name> [options]" >&2
  echo "Run capi-send.sh --help for full options" >&2
  exit 1
fi

PIXEL_ID="$1"
EVENT_NAME="$2"
shift 2

TOKEN=$(get_token)

# Defaults
EMAIL="" PHONE="" FIRST_NAME="" LAST_NAME=""
CITY="" STATE="" ZIP="" COUNTRY="" EXTERNAL_ID=""
VALUE="" CURRENCY="USD" URL="" EVENT_ID=""
IP="" UA="" FBP="" FBC=""
TEST_CODE="" CONTENT_IDS="" NUM_ITEMS=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --email)        EMAIL="$2"; shift 2 ;;
    --phone)        PHONE="$2"; shift 2 ;;
    --first-name)   FIRST_NAME="$2"; shift 2 ;;
    --last-name)    LAST_NAME="$2"; shift 2 ;;
    --city)         CITY="$2"; shift 2 ;;
    --state)        STATE="$2"; shift 2 ;;
    --zip)          ZIP="$2"; shift 2 ;;
    --country)      COUNTRY="$2"; shift 2 ;;
    --external-id)  EXTERNAL_ID="$2"; shift 2 ;;
    --value)        VALUE="$2"; shift 2 ;;
    --currency)     CURRENCY="$2"; shift 2 ;;
    --url)          URL="$2"; shift 2 ;;
    --event-id)     EVENT_ID="$2"; shift 2 ;;
    --ip)           IP="$2"; shift 2 ;;
    --ua)           UA="$2"; shift 2 ;;
    --fbp)          FBP="$2"; shift 2 ;;
    --fbc)          FBC="$2"; shift 2 ;;
    --test-code)    TEST_CODE="$2"; shift 2 ;;
    --content-ids)  CONTENT_IDS="$2"; shift 2 ;;
    --num-items)    NUM_ITEMS="$2"; shift 2 ;;
    --dry-run)      DRY_RUN=true; shift ;;
    --help)
      grep '^#' "$0" | head -40 | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Generate event ID if not provided
[[ -z "$EVENT_ID" ]] && EVENT_ID=$(gen_event_id)

NOW=$(date +%s)

echo ""
echo "========================================"
echo "CAPI EVENT SEND"
echo "Pixel: $PIXEL_ID"
echo "Event: $EVENT_NAME"
echo "Event ID: $EVENT_ID"
[[ -n "$TEST_CODE" ]] && echo "Mode: TEST ONLY (events_manager test events)"
echo "========================================"

# ---- Build user_data ----
echo ""
echo "Hashing user data..."

USER_DATA="{}"

# Hash PII fields
if [[ -n "$EMAIL" ]]; then
  HASH=$(hash_value "$EMAIL")
  USER_DATA=$(echo "$USER_DATA" | jq --arg v "$HASH" '. + {em: $v}')
  echo "  Email: hashed"
fi

if [[ -n "$PHONE" ]]; then
  HASH=$(hash_phone "$PHONE")
  USER_DATA=$(echo "$USER_DATA" | jq --arg v "$HASH" '. + {ph: $v}')
  echo "  Phone: hashed"
fi

if [[ -n "$FIRST_NAME" ]]; then
  HASH=$(hash_value "$FIRST_NAME")
  USER_DATA=$(echo "$USER_DATA" | jq --arg v "$HASH" '. + {fn: $v}')
  echo "  First name: hashed"
fi

if [[ -n "$LAST_NAME" ]]; then
  HASH=$(hash_value "$LAST_NAME")
  USER_DATA=$(echo "$USER_DATA" | jq --arg v "$HASH" '. + {ln: $v}')
  echo "  Last name: hashed"
fi

if [[ -n "$CITY" ]]; then
  HASH=$(hash_value "$CITY")
  USER_DATA=$(echo "$USER_DATA" | jq --arg v "$HASH" '. + {ct: $v}')
  echo "  City: hashed"
fi

if [[ -n "$STATE" ]]; then
  HASH=$(hash_value "$STATE")
  USER_DATA=$(echo "$USER_DATA" | jq --arg v "$HASH" '. + {st: $v}')
  echo "  State: hashed"
fi

if [[ -n "$ZIP" ]]; then
  # ZIP: digits only
  ZIP_DIGITS=$(echo "$ZIP" | tr -dc '0-9')
  HASH=$(echo -n "$ZIP_DIGITS" | sha256sum | cut -d' ' -f1)
  USER_DATA=$(echo "$USER_DATA" | jq --arg v "$HASH" '. + {zp: $v}')
  echo "  ZIP: hashed"
fi

if [[ -n "$COUNTRY" ]]; then
  HASH=$(hash_value "$COUNTRY")
  USER_DATA=$(echo "$USER_DATA" | jq --arg v "$HASH" '. + {country: $v}')
  echo "  Country: hashed"
fi

if [[ -n "$EXTERNAL_ID" ]]; then
  HASH=$(hash_value "$EXTERNAL_ID")
  USER_DATA=$(echo "$USER_DATA" | jq --arg v "$HASH" '. + {external_id: $v}')
  echo "  External ID: hashed"
fi

# Non-hashed fields
if [[ -n "$IP" ]]; then
  USER_DATA=$(echo "$USER_DATA" | jq --arg v "$IP" '. + {client_ip_address: $v}')
  echo "  IP: $IP"
fi

if [[ -n "$UA" ]]; then
  USER_DATA=$(echo "$USER_DATA" | jq --arg v "$UA" '. + {client_user_agent: $v}')
  echo "  User agent: set"
fi

if [[ -n "$FBP" ]]; then
  USER_DATA=$(echo "$USER_DATA" | jq --arg v "$FBP" '. + {fbp: $v}')
  echo "  FBP: $FBP"
fi

if [[ -n "$FBC" ]]; then
  USER_DATA=$(echo "$USER_DATA" | jq --arg v "$FBC" '. + {fbc: $v}')
  echo "  FBC: $FBC"
fi

# ---- Build event ----
EVENT=$(jq -n \
  --arg name "$EVENT_NAME" \
  --arg time "$NOW" \
  --arg id "$EVENT_ID" \
  --arg url "${URL:-}" \
  --argjson user_data "$USER_DATA" \
  '{
    event_name: $name,
    event_time: ($time | tonumber),
    event_id: $id,
    action_source: "website",
    user_data: $user_data
  } + (if $url != "" then {event_source_url: $url} else {} end)')

# Add custom_data if value or content IDs provided
if [[ -n "$VALUE" || -n "$CONTENT_IDS" ]]; then
  CUSTOM_DATA="{}"

  [[ -n "$CURRENCY" ]] && CUSTOM_DATA=$(echo "$CUSTOM_DATA" | jq --arg v "$CURRENCY" '. + {currency: $v}')
  [[ -n "$VALUE" ]]    && CUSTOM_DATA=$(echo "$CUSTOM_DATA" | jq --arg v "$VALUE" '. + {value: ($v | tonumber)}')
  [[ -n "$NUM_ITEMS" ]] && CUSTOM_DATA=$(echo "$CUSTOM_DATA" | jq --arg v "$NUM_ITEMS" '. + {num_items: ($v | tonumber)}')

  if [[ -n "$CONTENT_IDS" ]]; then
    # Build contents array from comma-separated IDs
    CONTENTS=$(echo "$CONTENT_IDS" | tr ',' '\n' | jq -R '{id: ., quantity: 1}' | jq -s '.')
    CUSTOM_DATA=$(echo "$CUSTOM_DATA" | jq --argjson c "$CONTENTS" '. + {contents: $c}')
  fi

  EVENT=$(echo "$EVENT" | jq --argjson cd "$CUSTOM_DATA" '. + {custom_data: $cd}')
fi

# ---- Build payload ----
PAYLOAD=$(jq -n --argjson event "$EVENT" '{data: [$event]}')

if [[ -n "$TEST_CODE" ]]; then
  PAYLOAD=$(echo "$PAYLOAD" | jq --arg tc "$TEST_CODE" '. + {test_event_code: $tc}')
fi

echo ""
echo "-- PAYLOAD --"
echo "$PAYLOAD" | jq .

if [[ "$DRY_RUN" == true ]]; then
  echo ""
  echo "[DRY RUN] Not sending. Remove --dry-run to send."
  exit 0
fi

# ---- Send ----
echo ""
echo "Sending..."

RESPONSE=$(curl -sf -X POST \
  "${API_BASE}/${PIXEL_ID}/events?access_token=${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" 2>&1 || echo '{"error":{"message":"curl failed"}}')

echo ""
echo "-- RESPONSE --"
echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"

EVENTS_RECEIVED=$(echo "$RESPONSE" | jq -r '.events_received // 0' 2>/dev/null || echo 0)
ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error.message // empty' 2>/dev/null || true)

echo ""
echo "========================================"
if [[ "$EVENTS_RECEIVED" -gt 0 ]]; then
  echo "SUCCESS -- events_received: $EVENTS_RECEIVED"
  echo "Event ID: $EVENT_ID"
  if [[ -n "$TEST_CODE" ]]; then
    echo ""
    echo "Check test events in Events Manager > Data Sources > [Pixel] > Test Events"
    echo "Test code: $TEST_CODE"
  fi
elif [[ -n "$ERROR_MSG" ]]; then
  echo "FAILED -- $ERROR_MSG"
else
  echo "UNKNOWN -- check response above"
fi
echo "========================================"
