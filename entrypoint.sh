#!/bin/sh
set -e

CONFIG_DIR="/home/node/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"
SEED_FILE="/app/config/openclaw.seed.json"

# First boot: seed config if no openclaw.json exists yet.
# The volume may be owned by root, so fix ownership before copying.
if [ ! -f "$CONFIG_FILE" ]; then
  echo "First boot detected — seeding config from $SEED_FILE"
  mkdir -p "$CONFIG_DIR"
  chown node:node "$CONFIG_DIR"
  cp "$SEED_FILE" "$CONFIG_FILE"
  chown node:node "$CONFIG_FILE"
fi

# Ensure the config dir is always writable by node (covers fresh volumes)
chown -R node:node "$CONFIG_DIR"

# Drop privileges and hand off to the CMD
exec su -s /bin/sh node -c 'exec "$@"' -- "$@"
