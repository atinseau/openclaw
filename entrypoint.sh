#!/bin/sh
set -e

CONFIG_DIR="/home/node/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"
SEED_FILE="/app/config/openclaw.seed.json"

# First boot: seed config if no openclaw.json exists yet
if [ ! -f "$CONFIG_FILE" ]; then
  echo "First boot detected — seeding config from $SEED_FILE"
  mkdir -p "$CONFIG_DIR"
  cp "$SEED_FILE" "$CONFIG_FILE"
fi

# Hand off to the original CMD (or whatever is passed as arguments)
exec "$@"
