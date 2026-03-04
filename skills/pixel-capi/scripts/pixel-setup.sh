#!/usr/bin/env bash
# pixel-setup.sh -- Generate platform-specific Meta Pixel + CAPI installation instructions
#
# Usage:
#   pixel-setup.sh <platform> <pixel_id>
#
# Platforms: nextjs, shopify, wordpress, webflow, ghl, clickfunnels, custom
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
  echo "ERROR: META_TOKEN not set" >&2
  exit 1
}

if [[ $# -lt 2 ]]; then
  echo "Usage: pixel-setup.sh <platform> <pixel_id>" >&2
  echo "Platforms: nextjs, shopify, wordpress, webflow, ghl, clickfunnels, custom" >&2
  exit 1
fi

PLATFORM="${1,,}"
PIXEL_ID="$2"
TOKEN=$(get_token)

# Fetch pixel name for display
PIXEL_NAME=$(curl -sf \
  "${API_BASE}/${PIXEL_ID}?fields=name&access_token=${TOKEN}" 2>/dev/null | \
  jq -r '.name // "Your Pixel"' 2>/dev/null || echo "Your Pixel")

echo ""
echo "========================================"
echo "PIXEL + CAPI SETUP GUIDE"
echo "Platform: $PLATFORM"
echo "Pixel: $PIXEL_NAME ($PIXEL_ID)"
echo "========================================"

# ---- Common header functions ----

print_dedup_note() {
  cat <<'EOF'

-- DEDUPLICATION (CRITICAL) --
Both pixel and CAPI must fire with the SAME event_id or conversions double-count.

Pattern:
  const eventId = 'evt_' + Date.now() + '_' + Math.random().toString(36).substr(2,9);
  fbq('track', 'Purchase', data, { eventID: eventId });  // browser
  // send same eventId to your server --> include in CAPI payload as event_id

EOF
}

print_fbp_fbc_note() {
  cat <<'EOF'

-- FBP + FBC COOKIES --
Read from browser cookies and pass to your CAPI endpoint:

  JavaScript (client-side):
  function getCookie(name) {
    const match = document.cookie.match(new RegExp('(^| )' + name + '=([^;]+)'));
    return match ? match[2] : null;
  }
  const fbp = getCookie('_fbp');  // e.g. fb.1.1234567890.987654321
  const fbc = getCookie('_fbc') || getFbcFromUrl();  // e.g. fb.1.1234567890.IwAR...

  function getFbcFromUrl() {
    const params = new URLSearchParams(window.location.search);
    const fbclid = params.get('fbclid');
    if (!fbclid) return null;
    return 'fb.1.' + Date.now() + '.' + fbclid;
  }

Pass fbp and fbc to your server with every event.

EOF
}

# ---- Platform guides ----

setup_nextjs() {
  cat <<EOF

== NEXT.JS SETUP (App Router + Pages Router) ==

STEP 1 -- Install pixel base code

For App Router (app/layout.tsx):

  import Script from 'next/script'

  export default function RootLayout({ children }) {
    return (
      <html>
        <body>
          {children}
          <Script id="fb-pixel" strategy="afterInteractive">
            {\`
              !function(f,b,e,v,n,t,s){if(f.fbq)return;n=f.fbq=function(){n.callMethod?
              n.callMethod.apply(n,arguments):n.queue.push(arguments)};
              if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';
              n.queue=[];t=b.createElement(e);t.async=!0;
              t.src=v;s=b.getElementsByTagName(e)[0];
              s.parentNode.insertBefore(t,s)}(window, document,'script',
              'https://connect.facebook.net/en_US/fbevents.js');
              fbq('init', '${PIXEL_ID}', {
                em: document.querySelector('[name=email]')?.value || '',
                // Add more advanced matching fields from your user session
              });
              fbq('track', 'PageView');
            \`}
          </Script>
        </body>
      </html>
    )
  }

STEP 2 -- Track standard events (client component)

  // components/TrackPurchase.tsx
  'use client'
  import { useEffect } from 'react'

  export function TrackPurchase({ orderId, value, currency = 'USD' }) {
    useEffect(() => {
      const eventId = 'purchase_' + orderId + '_' + Date.now();

      // Fire browser pixel
      window.fbq?.('track', 'Purchase', {
        value: value,
        currency: currency
      }, { eventID: eventId });

      // Fire CAPI (server-side)
      fetch('/api/capi', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          event_name: 'Purchase',
          event_id: eventId,
          value: value,
          currency: currency,
          fbp: getCookie('_fbp'),
          fbc: getCookie('_fbc'),
          url: window.location.href,
        })
      });
    }, []);
  }

STEP 3 -- Create CAPI API route (app/api/capi/route.ts)

  import { NextRequest, NextResponse } from 'next/server'
  import crypto from 'crypto'

  const PIXEL_ID = '${PIXEL_ID}'
  const ACCESS_TOKEN = process.env.META_CAPI_TOKEN!

  function sha256(value: string): string {
    return crypto.createHash('sha256').update(value.trim().toLowerCase()).digest('hex')
  }

  export async function POST(req: NextRequest) {
    const body = await req.json()
    const ip = req.headers.get('x-forwarded-for') ?? req.ip ?? ''
    const ua = req.headers.get('user-agent') ?? ''

    const userData: Record<string, string> = {
      client_ip_address: ip,
      client_user_agent: ua,
    }
    if (body.email) userData.em = sha256(body.email)
    if (body.phone) userData.ph = sha256(body.phone.replace(/\D/g, ''))
    if (body.firstName) userData.fn = sha256(body.firstName)
    if (body.lastName) userData.ln = sha256(body.lastName)
    if (body.fbp) userData.fbp = body.fbp
    if (body.fbc) userData.fbc = body.fbc

    const event: Record<string, unknown> = {
      event_name: body.event_name,
      event_time: Math.floor(Date.now() / 1000),
      event_id: body.event_id,
      event_source_url: body.url,
      action_source: 'website',
      user_data: userData,
    }

    if (body.value) {
      event.custom_data = {
        currency: body.currency || 'USD',
        value: body.value,
      }
    }

    const payload = { data: [event] }

    const res = await fetch(
      \`https://graph.facebook.com/v19.0/\${PIXEL_ID}/events?access_token=\${ACCESS_TOKEN}\`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      }
    )

    return NextResponse.json(await res.json())
  }

STEP 4 -- Environment variables (.env.local)

  META_CAPI_TOKEN=your_system_user_token_here

COMMON GOTCHAS:
- Fire fbq() only client-side (useEffect / 'use client') -- never in server components
- next/script with strategy="afterInteractive" ensures pixel loads after hydration
- Pass eventID in the third argument to fbq('track', ...) not second
- Use 'x-forwarded-for' header for real IP behind load balancers

EOF
  print_dedup_note
  print_fbp_fbc_note
}

setup_shopify() {
  cat <<EOF

== SHOPIFY SETUP ==

STEP 1 -- Enable Meta pixel natively (recommended)

  1. Shopify Admin > Online Store > Preferences
  2. Find "Facebook Pixel" section
  3. Enter Pixel ID: ${PIXEL_ID}
  4. Enable "Use Enhanced Ecommerce"

This fires: PageView, ViewContent, AddToCart, InitiateCheckout, Purchase

STEP 2 -- Enable CAPI via Meta Business Extension

  1. Shopify Admin > Apps > Meta (install if not already)
  2. Connect Meta Business Account
  3. Under "Data sharing settings" select "Maximum" mode
  4. This enables native CAPI with automatic matching

STEP 3 -- Custom CAPI for order events (via webhook)

  Create a webhook receiver (external server or Shopify function):

  Shopify webhook: orders/paid
  Endpoint: https://yoursite.com/webhooks/shopify-order

  Handler example (Node.js/Express):

    app.post('/webhooks/shopify-order', express.raw({type: 'application/json'}), async (req, res) => {
      const order = JSON.parse(req.body)
      const eventId = 'shopify_' + order.id + '_' + Date.now()

      await sendCAPI({
        event_name: 'Purchase',
        event_id: eventId,
        event_source_url: 'https://yourstore.com/thank-you',
        value: parseFloat(order.total_price),
        currency: order.currency,
        email: order.email,
        phone: order.phone,
        firstName: order.billing_address?.first_name,
        lastName: order.billing_address?.last_name,
        city: order.billing_address?.city,
        state: order.billing_address?.province_code,
        zip: order.billing_address?.zip,
        country: order.billing_address?.country_code,
      })

      res.status(200).send('OK')
    })

STEP 4 -- Advanced matching via theme.liquid

  Add before </head> in theme.liquid:

    {%- if customer -%}
    <script>
      fbq('init', '${PIXEL_ID}', {
        em: '{{ customer.email | sha256 }}',
        fn: '{{ customer.first_name | downcase | sha256 }}',
        ln: '{{ customer.last_name | downcase | sha256 }}',
        ph: '{{ customer.phone | sha256 }}',
      });
    {%- else -%}
    <script>
      fbq('init', '${PIXEL_ID}');
    {%- endif -%}
    </script>

COMMON GOTCHAS:
- Shopify Checkout (thank_you page) runs in a different domain/frame -- pixel may not fire
- Use server-side CAPI via webhook for reliable purchase tracking
- "Maximum" data sharing in Meta app enables CAPI with most matching params automatically
- Do NOT add pixel code manually if using the Meta app -- you'll get double-firing

EOF
}

setup_wordpress() {
  cat <<EOF

== WORDPRESS / WOOCOMMERCE SETUP ==

STEP 1 -- Install pixel base code

  Add to functions.php or via header plugin (e.g., "Insert Headers and Footers"):

    add_action('wp_head', function() {
      ?>
      <script>
        !function(f,b,e,v,n,t,s){if(f.fbq)return;n=f.fbq=function(){n.callMethod?
        n.callMethod.apply(n,arguments):n.queue.push(arguments)};
        if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';
        n.queue=[];t=b.createElement(e);t.async=!0;
        t.src=v;s=b.getElementsByTagName(e)[0];
        s.parentNode.insertBefore(t,s)}(window, document,'script',
        'https://connect.facebook.net/en_US/fbevents.js');

        <?php if (is_user_logged_in()): $user = wp_get_current_user(); ?>
        fbq('init', '${PIXEL_ID}', {
          em: '<?php echo hash('sha256', strtolower(trim(\$user->user_email))); ?>',
          fn: '<?php echo hash('sha256', strtolower(trim(\$user->first_name))); ?>',
          ln: '<?php echo hash('sha256', strtolower(trim(\$user->last_name))); ?>',
        });
        <?php else: ?>
        fbq('init', '${PIXEL_ID}');
        <?php endif; ?>

        fbq('track', 'PageView');
      </script>
      <?php
    });

STEP 2 -- WooCommerce purchase event

    // Fire Purchase on thank you page
    add_action('woocommerce_thankyou', function(\$order_id) {
      \$order = wc_get_order(\$order_id);
      \$event_id = 'wc_' . \$order_id . '_' . time();
      ?>
      <script>
        fbq('track', 'Purchase', {
          value: <?php echo \$order->get_total(); ?>,
          currency: '<?php echo get_woocommerce_currency(); ?>',
          order_id: '<?php echo \$order_id; ?>',
        }, { eventID: '<?php echo \$event_id; ?>' });
      </script>
      <?php

      // Also send CAPI
      \$billing = \$order->get_address('billing');
      wc_send_capi_purchase(\$order, \$event_id, \$billing);
    });

    function wc_send_capi_purchase(\$order, \$event_id, \$billing) {
      \$token = defined('META_CAPI_TOKEN') ? META_CAPI_TOKEN : get_option('meta_capi_token');
      \$pixel_id = '${PIXEL_ID}';

      \$user_data = [
        'client_ip_address' => \$_SERVER['REMOTE_ADDR'] ?? '',
        'client_user_agent' => \$_SERVER['HTTP_USER_AGENT'] ?? '',
      ];
      if (!empty(\$billing['email'])) \$user_data['em'] = hash('sha256', strtolower(trim(\$billing['email'])));
      if (!empty(\$billing['phone'])) \$user_data['ph'] = hash('sha256', preg_replace('/\D/', '', \$billing['phone']));
      if (!empty(\$billing['first_name'])) \$user_data['fn'] = hash('sha256', strtolower(trim(\$billing['first_name'])));
      if (!empty(\$billing['last_name'])) \$user_data['ln'] = hash('sha256', strtolower(trim(\$billing['last_name'])));

      \$payload = [
        'data' => [[
          'event_name' => 'Purchase',
          'event_time' => time(),
          'event_id' => \$event_id,
          'event_source_url' => wc_get_endpoint_url('order-received', \$order->get_id(), wc_get_checkout_url()),
          'action_source' => 'website',
          'user_data' => \$user_data,
          'custom_data' => [
            'currency' => \$order->get_currency(),
            'value' => floatval(\$order->get_total()),
          ],
        ]],
      ];

      wp_remote_post("https://graph.facebook.com/v19.0/\$pixel_id/events?access_token=\$token", [
        'body' => wp_json_encode(\$payload),
        'headers' => ['Content-Type' => 'application/json'],
      ]);
    }

STEP 3 -- Define META_CAPI_TOKEN in wp-config.php

    define('META_CAPI_TOKEN', 'your_system_user_token');

COMMON GOTCHAS:
- Caching plugins can prevent pixel from loading on first visit -- exclude checkout/thank-you pages from cache
- WooCommerce order total includes tax/shipping -- verify what Meta expects for your reporting
- Some hosting limits outbound HTTP -- test with wp_remote_post and check error logs

EOF
}

setup_webflow() {
  cat <<EOF

== WEBFLOW SETUP ==

Webflow has no server-side access, so CAPI requires an external webhook (n8n, Zapier, Make, or your own endpoint).

STEP 1 -- Add pixel base code

  Site Settings > Custom Code > Head Code:

    <script>
      !function(f,b,e,v,n,t,s){if(f.fbq)return;n=f.fbq=function(){n.callMethod?
      n.callMethod.apply(n,arguments):n.queue.push(arguments)};
      if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';
      n.queue=[];t=b.createElement(e);t.async=!0;
      t.src=v;s=b.getElementsByTagName(e)[0];
      s.parentNode.insertBefore(t,s)}(window, document,'script',
      'https://connect.facebook.net/en_US/fbevents.js');
      fbq('init', '${PIXEL_ID}');
      fbq('track', 'PageView');
    </script>

STEP 2 -- Track form submissions

  On pages with lead forms, add before </body>:

    <script>
      document.querySelector('form').addEventListener('submit', function(e) {
        const eventId = 'lead_' + Date.now() + '_' + Math.random().toString(36).substr(2,6);
        const email = document.querySelector('[type=email]')?.value || '';
        const phone = document.querySelector('[type=tel]')?.value || '';

        // Browser pixel
        fbq('track', 'Lead', {}, { eventID: eventId });

        // Send to webhook for CAPI
        fetch('https://your-n8n-or-webhook-url.com/fb-capi', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            event_name: 'Lead',
            event_id: eventId,
            email: email,
            phone: phone,
            fbp: document.cookie.match(/_fbp=([^;]+)/)?.[1] || '',
            fbc: document.cookie.match(/_fbc=([^;]+)/)?.[1] || new URLSearchParams(location.search).get('fbclid') && ('fb.1.' + Date.now() + '.' + new URLSearchParams(location.search).get('fbclid')),
            url: window.location.href,
            ip: '',  // webhook will read from request headers
            ua: navigator.userAgent,
          })
        });
      });
    </script>

STEP 3 -- Set up n8n webhook to send CAPI

  n8n webhook trigger -> HTTP Request node:

    URL: https://graph.facebook.com/v19.0/${PIXEL_ID}/events
    Method: POST
    Authentication: Header Auth (access_token = your token)

    Body (JSON):
    {
      "data": [{
        "event_name": "{{ \$json.event_name }}",
        "event_time": "{{ Math.floor(Date.now()/1000) }}",
        "event_id": "{{ \$json.event_id }}",
        "event_source_url": "{{ \$json.url }}",
        "action_source": "website",
        "user_data": {
          "em": "{{ \$json.email ? require('crypto').createHash('sha256').update(\$json.email.trim().toLowerCase()).digest('hex') : '' }}",
          "client_ip_address": "{{ \$headers['x-forwarded-for'] || \$headers['x-real-ip'] }}",
          "client_user_agent": "{{ \$json.ua }}",
          "fbp": "{{ \$json.fbp }}",
          "fbc": "{{ \$json.fbc }}"
        }
      }]
    }

COMMON GOTCHAS:
- Webflow sites can't run server code -- always route CAPI through an external service
- Use n8n self-hosted (Emerald's n8n) or Zapier/Make for the webhook handler
- IP must be read server-side from request headers -- client-side IP is unreliable

EOF
}

setup_ghl() {
  cat <<EOF

== GOHIGHLEVEL (GHL) SETUP ==

STEP 1 -- Enable native Meta pixel

  Funnels/Websites > [Select site] > Settings > Tracking:
  Enter Pixel ID: ${PIXEL_ID}

  GHL fires PageView automatically. For Lead events, configure:
  - Form submission tracking
  - Calendar booking tracking
  - Payment tracking

STEP 2 -- Enable CAPI via GHL native integration

  Settings > Integrations > Facebook:
  1. Connect your Facebook account
  2. Under "Conversions API" enable the integration
  3. Enter your System User Token (recommended) or User Token
  4. Select pixel: ${PIXEL_ID}
  5. Set data sharing level to "Maximum"

  GHL will automatically send server-side events for:
  - Lead form submissions
  - Calendar bookings
  - Order/payment completions

STEP 3 -- Custom CAPI for complex funnels (via GHL webhook)

  If GHL native CAPI isn't sufficient, use Workflow > Webhook action:

  Trigger: Form Submitted / Booking Created / Payment Received
  Action: Webhook

  URL: https://graph.facebook.com/v19.0/${PIXEL_ID}/events?access_token=YOUR_TOKEN
  Method: POST
  Content-Type: application/json

  Body:
  {
    "data": [{
      "event_name": "Lead",
      "event_time": {{contact.dateAdded | date: '%s'}},
      "event_id": "ghl_{{contact.id}}_{{''|date:'%s'}}",
      "event_source_url": "{{funnel.pageUrl}}",
      "action_source": "website",
      "user_data": {
        "em": "{{contact.email | sha256}}",
        "ph": "{{contact.phone | remove: '+' | sha256}}",
        "fn": "{{contact.firstName | downcase | sha256}}",
        "ln": "{{contact.lastName | downcase | sha256}}",
        "client_ip_address": "{{contact.ipAddress}}",
        "client_user_agent": "{{contact.userAgent}}"
      }
    }]
  }

  Note: GHL Liquid filters for sha256 may not be native -- pre-hash in a Function block if needed.

STEP 4 -- Advanced matching in GHL forms

  GHL automatically captures email and phone from form submissions.
  Enable advanced matching in Meta > Pixel settings to capture from auto-populated fields.

COMMON GOTCHAS:
- GHL's native CAPI sends events with a short delay -- not truly real-time
- Attribution window in GHL may differ from Meta -- set to "7-day click, 1-day view" to match
- Test with capi-test.sh to verify events arrive before relying on native integration
- GHL contact.ipAddress field may be empty -- verify before relying on it

EOF
}

setup_clickfunnels() {
  cat <<EOF

== CLICKFUNNELS 2.0 SETUP ==

STEP 1 -- Enable pixel in funnel settings

  Funnels > [Select funnel] > Settings > Tracking > Facebook Pixel ID:
  Enter: ${PIXEL_ID}

  CF2 automatically fires PageView and Lead (form submission).
  For Purchase, configure in the Order page step.

STEP 2 -- Enable CAPI (CF2 native, currently beta)

  Workspace Settings > Integrations > Meta:
  1. Connect Facebook account
  2. Enter System User Token
  3. Select pixel: ${PIXEL_ID}
  4. Enable "Send CAPI events"

  CF2 will mirror browser pixel events server-side with the same event_id.

STEP 3 -- Custom CAPI via CF2 webhooks (fallback / additional events)

  Funnels > Automation > Webhook:
  Trigger: Purchase / Opt-in / etc.

  URL: https://graph.facebook.com/v19.0/${PIXEL_ID}/events?access_token=YOUR_TOKEN
  Method: POST

  Map contact fields to CAPI payload manually.
  CF2 provides: email, phone, first_name, last_name, ip_address, user_agent

STEP 4 -- Custom code for advanced matching

  Funnel > [Page] > Settings > Head Tracking Code:

    <script>
      fbq('init', '${PIXEL_ID}', {
        em: '{{contact.email | sha256}}',
        ph: '{{contact.phone | sha256}}',
        fn: '{{contact.first_name | lowercase | sha256}}',
        ln: '{{contact.last_name | lowercase | sha256}}',
      });
    </script>

COMMON GOTCHAS:
- CF2 CAPI integration is newer -- verify it's sending by checking Test Events tool
- Order bumps and upsells fire separate purchase events -- ensure dedup event_ids are unique per order
- CF2 Liquid syntax for sha256 may vary -- test before going live

EOF
}

setup_custom() {
  cat <<EOF

== CUSTOM / VANILLA JS SETUP ==

STEP 1 -- Base pixel code (add to <head> of every page)

    <script>
      !function(f,b,e,v,n,t,s){if(f.fbq)return;n=f.fbq=function(){n.callMethod?
      n.callMethod.apply(n,arguments):n.queue.push(arguments)};
      if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';
      n.queue=[];t=b.createElement(e);t.async=!0;
      t.src=v;s=b.getElementsByTagName(e)[0];
      s.parentNode.insertBefore(t,s)}(window, document,'script',
      'https://connect.facebook.net/en_US/fbevents.js');

      // Advanced matching -- pass hashed user data if known at page load
      fbq('init', '${PIXEL_ID}', {
        // em: 'sha256_hashed_email',   // populate server-side if user is logged in
        // ph: 'sha256_hashed_phone',
      });
      fbq('track', 'PageView');
    </script>
    <noscript>
      <img height="1" width="1" style="display:none"
        src="https://www.facebook.com/tr?id=${PIXEL_ID}&ev=PageView&noscript=1"/>
    </noscript>

STEP 2 -- Standard events

    // ViewContent
    fbq('track', 'ViewContent', { content_ids: ['SKU123'], content_type: 'product', value: 29.99, currency: 'USD' });

    // AddToCart
    fbq('track', 'AddToCart', { content_ids: ['SKU123'], value: 29.99, currency: 'USD' });

    // InitiateCheckout
    fbq('track', 'InitiateCheckout', { value: 29.99, currency: 'USD', num_items: 1 });

    // Purchase (with dedup)
    const eventId = 'purchase_' + orderId + '_' + Date.now();
    fbq('track', 'Purchase', { value: 109.97, currency: 'USD' }, { eventID: eventId });
    // --> send eventId to your server

    // Lead
    const leadEventId = 'lead_' + Date.now() + '_' + Math.random().toString(36).substr(2,6);
    fbq('track', 'Lead', {}, { eventID: leadEventId });

STEP 3 -- Server-side CAPI endpoint (bash/curl example)

  Your server receives the eventId and user data, then calls:

    curl -s -X POST "https://graph.facebook.com/v19.0/${PIXEL_ID}/events" \
      -H "Content-Type: application/json" \
      -d '{
        "access_token": "YOUR_TOKEN",
        "data": [{
          "event_name": "Purchase",
          "event_time": '"\$(date +%s)"',
          "event_id": "purchase_ORDER123_'"\$(date +%s%3N)"'",
          "event_source_url": "https://yoursite.com/thank-you",
          "action_source": "website",
          "user_data": {
            "em": "'"\$(echo -n 'user@example.com' | sha256sum | cut -d' ' -f1)"'",
            "ph": "'"\$(echo -n '15551234567' | sha256sum | cut -d' ' -f1)"'",
            "client_ip_address": "USER_IP",
            "client_user_agent": "USER_AGENT",
            "fbp": "fb.1.1234567890.987654321",
            "fbc": "fb.1.1234567890.IwAR..."
          },
          "custom_data": {
            "currency": "USD",
            "value": 109.97
          }
        }]
      }'

STEP 4 -- Hashing reference (SHA-256)

  Email:     echo -n "user@example.com" | sha256sum | cut -d' ' -f1
  Phone:     echo -n "15551234567" | sha256sum | cut -d' ' -f1   # digits only, with country code
  Name:      echo -n "john" | sha256sum | cut -d' ' -f1           # lowercase, trimmed
  City:      echo -n "new york" | sha256sum | cut -d' ' -f1       # lowercase
  State:     echo -n "ny" | sha256sum | cut -d' ' -f1             # 2-letter, lowercase
  ZIP:       echo -n "10001" | sha256sum | cut -d' ' -f1          # digits only
  Country:   echo -n "us" | sha256sum | cut -d' ' -f1             # 2-letter ISO, lowercase

EOF
  print_dedup_note
  print_fbp_fbc_note
}

# ---- Dispatch ----
case "$PLATFORM" in
  nextjs)       setup_nextjs ;;
  shopify)      setup_shopify ;;
  wordpress)    setup_wordpress ;;
  webflow)      setup_webflow ;;
  ghl)          setup_ghl ;;
  clickfunnels) setup_clickfunnels ;;
  custom)       setup_custom ;;
  *)
    echo "Unknown platform: $PLATFORM" >&2
    echo "Supported: nextjs, shopify, wordpress, webflow, ghl, clickfunnels, custom" >&2
    exit 1
    ;;
esac

echo ""
echo "========================================"
echo "NEXT STEPS:"
echo "  1. Implement the code above"
echo "  2. Test with: capi-test.sh ${PIXEL_ID}"
echo "  3. Check EMQ with: emq-check.sh ${PIXEL_ID}"
echo "  4. Verify in Events Manager > Test Events"
echo "========================================"
