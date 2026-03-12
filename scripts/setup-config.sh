#!/bin/sh
set -e

CONFIG_DIR="/home/node/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"
SEED_FILE="/app/config/openclaw.json"

RESOLVED_SEED=$(sed "s|__OPENCLAW_DOMAIN__|${OPENCLAW_DOMAIN}|g" "$SEED_FILE")

if [ ! -f "$CONFIG_FILE" ]; then
  echo "First boot — writing seed config (domain=$OPENCLAW_DOMAIN)"
  echo "$RESOLVED_SEED" > "$CONFIG_FILE"
else
  echo "Deep-merging seed config into existing config (domain=$OPENCLAW_DOMAIN)"
  MERGED=$(jq -s '.[0] * .[1]' "$CONFIG_FILE" - <<EOF
$RESOLVED_SEED
EOF
  )
  echo "$MERGED" > "$CONFIG_FILE"
fi

echo "Config ready."
