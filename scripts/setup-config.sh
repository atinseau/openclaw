#!/bin/sh
set -e

CONFIG_DIR="/home/node/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"
SEED_FILE="/app/config/openclaw.json"

# ── Resolve placeholders in seed config ─────────────────────────
# OPENCLAW_DOMAIN  → controlUi.allowedOrigins
# BROWSERLESS_CDP_URL → browser.profiles.browserless.cdpUrl
RESOLVED_SEED=$(sed \
  -e "s|__OPENCLAW_DOMAIN__|${OPENCLAW_DOMAIN}|g" \
  -e "s|__BROWSERLESS_CDP_URL__|${BROWSERLESS_CDP_URL:-http://browserless:3000}|g" \
  "$SEED_FILE")

if [ ! -f "$CONFIG_FILE" ]; then
  echo "First boot — writing seed config (domain=$OPENCLAW_DOMAIN, browserless=$BROWSERLESS_CDP_URL)"
  echo "$RESOLVED_SEED" > "$CONFIG_FILE"
else
  echo "Deep-merging seed config into existing config (domain=$OPENCLAW_DOMAIN, browserless=$BROWSERLESS_CDP_URL)"
  MERGED=$(jq -s '.[0] * .[1]' "$CONFIG_FILE" - <<EOF
$RESOLVED_SEED
EOF
  )
  echo "$MERGED" > "$CONFIG_FILE"
fi

# ── Safety net: let openclaw doctor remove any invalid/stale keys ──
# This catches schema violations such as keys that were written by a
# previous seed but are no longer recognised by the current version.
if command -v openclaw >/dev/null 2>&1; then
  echo "Running openclaw doctor --fix …"
  openclaw doctor --fix 2>&1 || true
fi

echo "Config ready."
