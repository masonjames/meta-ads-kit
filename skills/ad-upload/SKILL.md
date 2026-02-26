---
name: ad-upload
description: "Push ad copy and images to Meta via Graph API — no Ads Manager required. Uploads images, builds asset_feed_spec creatives, and creates or refreshes ads in existing ad sets. Downstream of ad-copy-generator."
metadata:
  openclaw:
    emoji: "🚀"
    user-invocable: true
    homepage: https://github.com/TheMattBerman/meta-ads-kit
    requires:
      env:
        - FACEBOOK_ACCESS_TOKEN
        - META_AD_ACCOUNT
---

# Ad Upload

Take the copy and images from `ad-copy-generator` and push them straight to Meta. No copy-paste into Ads Manager. No manual creative setup. Just: generate, review, upload.

This skill handles the full upload chain: image → hash → creative (with asset_feed_spec) → ad.

Read `workspace/brand/` per the _vibe-system protocol if available.

---

## Brand Memory Integration

**Reads:** `stack.md`, `assets.md`, `learnings.md` (all optional)

| File | What it provides |
|------|-----------------|
| `workspace/brand/stack.md` | Stored ad account ID, default ad set IDs, target CPA |
| `workspace/brand/assets.md` | Index of existing creatives and their IDs |
| `workspace/brand/learnings.md` | Past upload patterns, what's worked |

**Writes:**

| File | What it contains |
|------|-----------------|
| `workspace/brand/assets.md` | Appends uploaded creative IDs and ad IDs |
| `workspace/campaigns/{name}/ads/{creative}.upload.json` | Full API response — creative ID, ad ID, status |

---

## Setup

### Token

```bash
# Get your Facebook access token
TOKEN=$(jq -r '.profiles.default.tokens.facebook' ~/.social-cli/config.json)
export FACEBOOK_ACCESS_TOKEN=$TOKEN

# Verify it works
curl -s "https://graph.facebook.com/v22.0/me?access_token=$FACEBOOK_ACCESS_TOKEN" | jq .
```

### Ad Account

```bash
# List ad accounts you have access to
curl -s "https://graph.facebook.com/v22.0/me/adaccounts?fields=id,name&access_token=$FACEBOOK_ACCESS_TOKEN" | jq '.data[]'

export META_AD_ACCOUNT="act_123456789"
```

Store in `workspace/brand/stack.md` so you don't set these every time:
```
ad_account: act_123456789
default_adset_id: 23847293847
```

---

## The Upload Chain

Every ad goes through four steps:

```
1. Validate copy + image
       |
2. Upload image → get hash
       |
3. Create creative with asset_feed_spec
       |
4. Create ad (or update existing)
```

---

## Step 1: Validate Before Uploading

Run validation before touching the API. Catch errors locally.

### Copy Validation

| Element | Rule | Error |
|---------|------|-------|
| Headline | Max 40 chars (hard stop at 50) | "Headline '[text]' is [N] chars — truncates on mobile" |
| Body | 50-500 chars per variant | "Body V1 too short (<50 chars)" |
| Description | Max 30 chars | "Description too long — will be cut off" |
| Titles array | At least 1, max 5 | "Need at least 1 title" |
| Bodies array | At least 1, max 5 | "Need at least 1 body" |
| Call to action | Must be valid Meta CTA type | "LEARN_MORE is valid; 'click here' is not" |

### Valid Meta CTA Types
```
LEARN_MORE, SHOP_NOW, SIGN_UP, BOOK_TRAVEL, DOWNLOAD,
GET_OFFER, GET_QUOTE, SUBSCRIBE, WATCH_MORE, APPLY_NOW,
CONTACT_US, GET_DIRECTIONS, ORDER_NOW, REQUEST_TIME,
SEE_MENU, SEND_MESSAGE, BUY_TICKETS, CALL_NOW
```

### Image Validation

| Check | Rule |
|-------|------|
| File exists | Error if path not found |
| Format | JPG or PNG only (no WebP for carousel/DPA) |
| File size | Under 30MB |
| Dimensions | Min 600x600px; recommended 1080x1080 (square) or 1080x1350 (4:5) |
| Aspect ratio | 1:1, 4:5, 16:9, or 9:16 — no odd ratios |
| Text overlay | Warn if >20% text (Meta's rule, not enforced but affects delivery) |

```bash
# Check image dimensions
identify -format "%wx%h" image.jpg   # requires ImageMagick
# Or:
python3 -c "from PIL import Image; img=Image.open('image.jpg'); print(img.size)"
```

### Dry-Run Mode

Add `--dry-run` to any operation to see exactly what would be sent without hitting the API:

```
"Upload these ads -- dry run first"
"Dry run: push creative for summer-sale campaign"
```

Dry-run output shows:
- Validation results
- Exact JSON payload that would be sent to each endpoint
- Estimated creative/ad names
- No API calls made, no IDs returned

---

## Step 2: Upload Images

### Single Image Upload

```bash
TOKEN="$FACEBOOK_ACCESS_TOKEN"
ACCOUNT="$META_AD_ACCOUNT"  # e.g. act_123456789
IMAGE_PATH="/path/to/image.jpg"
IMAGE_NAME="summer-sale-hero.jpg"

curl -s \
  -F "filename=$IMAGE_NAME" \
  -F "source=@$IMAGE_PATH" \
  "https://graph.facebook.com/v22.0/$ACCOUNT/adimages?access_token=$TOKEN" \
  | jq .
```

**Response:**
```json
{
  "images": {
    "summer-sale-hero.jpg": {
      "hash": "a1b2c3d4e5f6789abc...",
      "url": "https://www.facebook.com/ads/image/?d=...",
      "width": 1080,
      "height": 1080
    }
  }
}
```

Extract the hash:
```bash
HASH=$(curl -s \
  -F "filename=$IMAGE_NAME" \
  -F "source=@$IMAGE_PATH" \
  "https://graph.facebook.com/v22.0/$ACCOUNT/adimages?access_token=$TOKEN" \
  | jq -r ".images[\"$IMAGE_NAME\"].hash")

echo "Image hash: $HASH"
```

### Batch Image Upload (multiple files)

```bash
# Upload multiple images in one call
curl -s \
  -F "filename[0]=hero-v1.jpg" \
  -F "source[0]=@/path/to/hero-v1.jpg" \
  -F "filename[1]=hero-v2.jpg" \
  -F "source[1]=@/path/to/hero-v2.jpg" \
  "https://graph.facebook.com/v22.0/$ACCOUNT/adimages?access_token=$TOKEN" \
  | jq .
```

### Check Existing Image by Hash

If you think an image is already uploaded (check `workspace/brand/assets.md`):

```bash
curl -s \
  "https://graph.facebook.com/v22.0/$ACCOUNT/adimages?hashes=['HASH_HERE']&access_token=$TOKEN" \
  | jq .
```

---

## Step 3: Create Ad Creative (asset_feed_spec)

This is Meta's Degrees of Freedom format. You provide multiple headlines, bodies, descriptions, and images — Meta automatically tests combinations across placements.

### Full asset_feed_spec Creative

```bash
ACCOUNT="$META_AD_ACCOUNT"
TOKEN="$FACEBOOK_ACCESS_TOKEN"
PAGE_ID="YOUR_FACEBOOK_PAGE_ID"
IMAGE_HASH="a1b2c3d4..."  # from Step 2
PIXEL_ID="YOUR_PIXEL_ID"  # optional but recommended

curl -s \
  -X POST \
  "https://graph.facebook.com/v22.0/$ACCOUNT/adcreatives" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Summer Sale - Multi-Copy v1",
    "object_story_spec": {
      "page_id": "'"$PAGE_ID"'"
    },
    "asset_feed_spec": {
      "bodies": [
        {"text": "Your V1 body copy here. Pain point opener, specific stat, soft CTA."},
        {"text": "Your V2 body copy here. Different angle, different psychology."},
        {"text": "Your V3 body copy here. Social proof heavy. Numbers up front."}
      ],
      "titles": [
        {"text": "Headline One - 35 Chars"},
        {"text": "Question Headline?"},
        {"text": "Stat-Driven: 3X Results"}
      ],
      "descriptions": [
        {"text": "Supporting benefit statement."},
        {"text": "Secondary proof point."}
      ],
      "images": [
        {"hash": "'"$IMAGE_HASH"'"}
      ],
      "call_to_actions": [
        {
          "type": "LEARN_MORE",
          "value": {
            "link": "https://yoursite.com/landing-page",
            "link_caption": "yoursite.com"
          }
        }
      ],
      "optimization_type": "DEGREES_OF_FREEDOM"
    },
    "degrees_of_freedom_spec": {
      "creative_features_spec": {
        "standard_enhancements": {"enroll_status": "OPT_IN"}
      }
    },
    "access_token": "'"$TOKEN"'"
  }' \
  | jq .
```

**Response:**
```json
{
  "id": "23847293847293847"
}
```

That `id` is your `CREATIVE_ID` for Step 4.

### Multiple Images in asset_feed_spec

```bash
"images": [
  {"hash": "hash_for_image_1"},
  {"hash": "hash_for_image_2"},
  {"hash": "hash_for_image_3"}
]
```

Meta will test copy + image combinations. 3 images × 3 headlines × 3 bodies = 27 combinations. Meta's algorithm finds the winners.

### Verify Creative Was Created

```bash
CREATIVE_ID="23847293847293847"

curl -s \
  "https://graph.facebook.com/v22.0/$CREATIVE_ID?fields=id,name,status,asset_feed_spec&access_token=$TOKEN" \
  | jq .
```

---

## Step 4: Create Ad

### Create New Ad

```bash
ACCOUNT="$META_AD_ACCOUNT"
TOKEN="$FACEBOOK_ACCESS_TOKEN"
ADSET_ID="23847000000001"  # existing ad set ID
CREATIVE_ID="23847293847293847"  # from Step 3

curl -s \
  -X POST \
  "https://graph.facebook.com/v22.0/$ACCOUNT/ads" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Summer Sale - Multi-Copy v1",
    "adset_id": "'"$ADSET_ID"'",
    "creative": {
      "creative_id": "'"$CREATIVE_ID"'"
    },
    "status": "PAUSED",
    "access_token": "'"$TOKEN"'"
  }' \
  | jq .
```

**Always create as PAUSED first. Review in Ads Manager before activating.**

**Response:**
```json
{
  "id": "23847111111111111"
}
```

### Create Ad with Tracking Spec

```bash
curl -s \
  -X POST \
  "https://graph.facebook.com/v22.0/$ACCOUNT/ads" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Summer Sale - Multi-Copy v1",
    "adset_id": "'"$ADSET_ID"'",
    "creative": {
      "creative_id": "'"$CREATIVE_ID"'"
    },
    "status": "PAUSED",
    "tracking_specs": [
      {
        "action.type": ["offsite_conversion"],
        "fb_pixel": ["'"$PIXEL_ID"'"]
      }
    ],
    "access_token": "'"$TOKEN"'"
  }' \
  | jq .
```

### Activate an Ad (after review)

```bash
AD_ID="23847111111111111"

curl -s \
  -X POST \
  "https://graph.facebook.com/v22.0/$AD_ID" \
  -d "status=ACTIVE&access_token=$TOKEN" \
  | jq .
```

---

## Update Existing Ad (Copy Refresh)

When a creative is fatigued, don't rebuild from scratch — swap in fresh copy.

### Step 1: Get Current Creative

```bash
AD_ID="23847111111111111"

curl -s \
  "https://graph.facebook.com/v22.0/$AD_ID?fields=creative{id,name,asset_feed_spec}&access_token=$TOKEN" \
  | jq .
```

### Step 2: Create New Creative with Fresh Copy

Run Step 3 above with updated bodies/titles/descriptions.

### Step 3: Attach New Creative to Existing Ad

```bash
NEW_CREATIVE_ID="23847999999999999"

curl -s \
  -X POST \
  "https://graph.facebook.com/v22.0/$AD_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "creative": {
      "creative_id": "'"$NEW_CREATIVE_ID"'"
    },
    "access_token": "'"$TOKEN"'"
  }' \
  | jq .
```

Note: You're replacing the creative on the existing ad. The ad ID stays the same (metrics history preserved). The old creative still exists — it's just detached from this ad.

---

## Batch Mode

Upload copy for multiple ads in one session.

### Batch Input Format

Reads from `workspace/campaigns/{name}/ads/batch-upload.json`:

```json
{
  "campaign": "summer-sale-2026",
  "adset_id": "23847000000001",
  "page_id": "123456789",
  "destination_url": "https://yoursite.com/lp",
  "ads": [
    {
      "name": "hero-notes-app",
      "image_path": "/path/to/notes-app.jpg",
      "asset_feed_spec_path": "workspace/campaigns/summer-sale-2026/ads/notes-app.json"
    },
    {
      "name": "hero-receipt",
      "image_path": "/path/to/receipt.jpg",
      "asset_feed_spec_path": "workspace/campaigns/summer-sale-2026/ads/receipt.json"
    }
  ]
}
```

### Batch Upload Process

```
"Upload all ads in summer-sale-2026 campaign"
"Batch upload ads from batch-upload.json"
```

For each ad in the batch:
1. Validate copy + image
2. Upload image → get hash
3. Create creative
4. Create ad (PAUSED)
5. Log result

Show progress as each completes:
```
[1/3] notes-app — image uploaded (hash: a1b2c...) — creative created (ID: 238472...) — ad created (ID: 238471...) PAUSED
[2/3] receipt — image uploaded (hash: d4e5f...) — creative created (ID: 238473...) — ad created (ID: 238474...) PAUSED
[3/3] hero-split — image uploaded (hash: g7h8i...) — creative created (ID: 238475...) — ad created (ID: 238476...) PAUSED

Batch complete: 3 ads created, all PAUSED
Review at: https://www.facebook.com/adsmanager/manage/ads
```

---

## Error Handling

### Common Graph API Errors

| Error Code | Meaning | Fix |
|------------|---------|-----|
| `190` | Token expired or invalid | Re-auth: `social auth login` |
| `200` | Permission missing | Add `ads_management` scope to token |
| `294` | Managing ads over rate limit | Back off 60s, retry |
| `100` | Invalid parameter | Check field names and values |
| `2615` | Creative rejected by policy | Check text overlay %, prohibited content |
| `1487395` | Image hash invalid | Re-upload image — hash may have expired |
| `368` | Temporarily blocked | Account flagged, review in Ads Manager |

### Token Expiry (Error 190)

```bash
# Check token validity
curl -s "https://graph.facebook.com/v22.0/debug_token?\
input_token=$FACEBOOK_ACCESS_TOKEN\
&access_token=$FACEBOOK_ACCESS_TOKEN" | jq '.data | {valid, expires_at, scopes}'

# If expired, re-auth
social auth login
# Then re-export
export FACEBOOK_ACCESS_TOKEN=$(jq -r '.profiles.default.tokens.facebook' ~/.social-cli/config.json)
```

### Rate Limits (Error 294)

Meta's Marketing API uses a score-based rate limit, not a simple per-minute cap. Back off with exponential retry:

```bash
# Simple retry wrapper
upload_with_retry() {
  local max_retries=3
  local wait=10
  for i in $(seq 1 $max_retries); do
    result=$(eval "$@")
    if echo "$result" | jq -e '.error.code == 294' > /dev/null 2>&1; then
      echo "Rate limited. Waiting ${wait}s (attempt $i/$max_retries)..."
      sleep $wait
      wait=$((wait * 2))
    else
      echo "$result"
      return
    fi
  done
  echo "Max retries hit. Last response: $result"
}
```

### Permission Issues (Error 200)

Token needs `ads_management` scope:
```bash
social auth login --scopes "ads_read,ads_management,pages_read_engagement"
```

### Image Rejected

If the creative API returns a policy rejection on the image:
1. Check text overlay percentage (>20% often rejected)
2. Remove any prohibited content (alcohol with people <25, misleading imagery)
3. Try a cropped or reframed version of the image

---

## Invocation Patterns

```
"Upload the summer-sale ads to Meta"
"Push this creative to ad set 238470000001"
"Refresh copy on ad ID 238471111111"
"Batch upload all ads in the Q2 campaign"
"Dry run: what would happen if I uploaded these ads?"
"Upload ad but don't activate it yet"
```

### Decision Tree

```
User asks to upload →
  Have asset_feed_spec JSON? (from ad-copy-generator)
    NO  → Run ad-copy-generator first, then come back
    YES → Check for images
  Have images?
    NO  → Ask: "What images should these ads use?"
    YES → Validate copy + images
  Validation pass?
    NO  → Show errors, stop until fixed
    YES → Dry-run mode?
      YES → Show what would happen, no API calls
      NO  → Run upload chain: image → creative → ad (PAUSED)
  Ad created?
    YES → Save IDs to campaign files, show review link
    NO  → Show error with specific fix
```

---

## Campaign File Output

After each upload, save results:

```
workspace/campaigns/{campaign-name}/ads/
  {creative-name}.json             <- asset_feed_spec (from ad-copy-generator)
  {creative-name}.upload.json      <- API response (creative ID, ad ID, status)
  {creative-name}.md               <- Human-readable copy document
```

### upload.json format

```json
{
  "uploaded_at": "2026-02-26T00:00:00Z",
  "campaign": "summer-sale-2026",
  "ad_name": "hero-notes-app",
  "image_hash": "a1b2c3d4e5f6789abc",
  "creative_id": "23847293847293847",
  "ad_id": "23847111111111111",
  "adset_id": "23847000000001",
  "status": "PAUSED",
  "review_url": "https://www.facebook.com/adsmanager/manage/ads?act=123456789"
}
```

Append to `workspace/brand/assets.md`:
```
| summer-sale-2026 hero-notes-app | ad | 2026-02-26 | creative: 238472... ad: 238471... | PAUSED |
```

---

## Integration

This skill is the downstream piece of the Meta Ads Copilot ecosystem:

- **Upstream (required):** `ad-copy-generator` — produces the asset_feed_spec JSON and copy variants that this skill uploads
- **Upstream (trigger):** `ad-creative-monitor` — detects creative fatigue and flags ads that need copy refresh; hand off to this skill to push fresh copy
- **Downstream:** `meta-ads` — monitor performance of the ads this skill just created; check if new copy is outperforming old

### Typical Full Workflow

```
1. meta-ads          → "Ad #238471 has frequency 4.2, CTR dropped 40% — refresh needed"
2. ad-copy-generator → Write 3 new body variants + 3 headlines matched to the image
3. ad-upload         → Push fresh creative, attach to existing ad (preserves ad ID and history)
4. meta-ads          → Monitor new creative performance next 7 days
```

### File Handoff

`ad-copy-generator` saves to:
```
workspace/campaigns/{name}/ads/{creative}.json  ← asset_feed_spec ready for API
```

This skill reads from the same path. Zero copy-paste.

---

## Anti-Patterns

- **Activating ads immediately** — Always create as PAUSED, review in Ads Manager first
- **Uploading without dry-run on first use** — Use dry-run until you've confirmed the chain works end-to-end
- **Ignoring validation errors** — Headline truncation kills CTR; fix it before uploading
- **Uploading duplicate images** — Check `workspace/brand/assets.md` for existing hashes first
- **One-size copy across all placements** — asset_feed_spec exists so Meta can optimize per placement; give it options (3+ bodies, 3+ titles)
- **Using WebP images** — Meta accepts them sometimes but rejects them in specific placements; stick to JPG/PNG
- **Hard-coding token in scripts** — Always read from `~/.social-cli/config.json` or env var; never commit tokens
- **Skipping the page ID** — Creative will fail without a valid Facebook Page ID in `object_story_spec`
- **Not saving upload responses** — If you don't save the creative ID and ad ID, you can't update or monitor later
- **Creating new ad for copy refresh** — Update the creative on the existing ad to preserve metric history and delivery algorithm learning
