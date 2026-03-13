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

# ── Safety net: validate config, run doctor --fix only if invalid ──
# This catches schema violations such as keys that were written by a
# previous seed but are no longer recognised by the current version.
echo "Validating config …"
if ! openclaw config validate 2>&1; then
  echo "Config invalid — running doctor --fix …"
  openclaw doctor --fix --non-interactive 2>&1 || true

  echo "Re-validating config …"
  if ! openclaw config validate 2>&1; then
    echo "ERROR: config still invalid after doctor --fix — fix openclaw.json manually and redeploy."
    exit 1
  fi
fi

echo "Config ready."

# ── Seed avatars into the persistent workspace ──────────────────
# Copy bundled avatars to the workspace volume if they don't already
# exist, so IDENTITY.md can reference avatars/jarvis.png.
WORKSPACE_DIR="/home/node/.openclaw/workspace"
AVATARS_SRC="/app/avatars"
AVATARS_DST="$WORKSPACE_DIR/avatars"

if [ -d "$AVATARS_SRC" ]; then
  mkdir -p "$AVATARS_DST"
  for f in "$AVATARS_SRC"/*; do
    fname="$(basename "$f")"
    if [ ! -f "$AVATARS_DST/$fname" ]; then
      echo "Seeding avatar: $fname"
      cp "$f" "$AVATARS_DST/$fname"
    fi
  done
fi
