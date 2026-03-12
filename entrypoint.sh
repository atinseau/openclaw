#!/bin/sh
set -e

CONFIG_DIR="/home/node/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"
SEED_FILE="/app/config/openclaw.json"

# Require OPENCLAW_DOMAIN — no fallback
if [ -z "$OPENCLAW_DOMAIN" ]; then
  echo "ERROR: OPENCLAW_DOMAIN is required (e.g. openclaw.example.com)"
  echo "Set it in Coolify environment variables and redeploy."
  exit 1
fi

# Resolve seed config with OPENCLAW_DOMAIN injected
RESOLVED_SEED=$(sed "s|__OPENCLAW_DOMAIN__|${OPENCLAW_DOMAIN}|g" "$SEED_FILE")

mkdir -p "$CONFIG_DIR"
chown node:node "$CONFIG_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
  # First boot — write seed config as-is
  echo "First boot — writing seed config (domain=$OPENCLAW_DOMAIN)"
  echo "$RESOLVED_SEED" > "$CONFIG_FILE"
else
  # Subsequent boot — deep merge seed into existing config
  # Seed values (right) override existing (left) for matching keys;
  # user-added keys not in the seed are preserved.
  echo "Deep-merging seed config into existing config (domain=$OPENCLAW_DOMAIN)"
  MERGED=$(jq -s '.[0] * .[1]' "$CONFIG_FILE" - <<EOF
$RESOLVED_SEED
EOF
  )
  echo "$MERGED" > "$CONFIG_FILE"
fi

chown node:node "$CONFIG_FILE"

# Ensure the full config dir is writable by node (covers fresh volumes)
chown -R node:node "$CONFIG_DIR"

# Drop privileges and hand off to the CMD
exec su -s /bin/sh node -c 'exec "$@"' -- "$@"
