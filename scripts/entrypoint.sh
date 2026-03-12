#!/bin/sh
set -e

CONFIG_DIR="/home/node/.openclaw"
WORKSPACE_DIR="$CONFIG_DIR/workspace"

# ── Require OPENCLAW_DOMAIN ─────────────────────────────────────
if [ -z "$OPENCLAW_DOMAIN" ]; then
  echo "ERROR: OPENCLAW_DOMAIN is required (e.g. openclaw.example.com)"
  echo "Set it in Coolify environment variables and redeploy."
  exit 1
fi

# ── Fix volume ownership (only thing we do as root) ─────────────
echo "Fixing volume ownership …"
chown node:node "$CONFIG_DIR"
mkdir -p "$WORKSPACE_DIR"
chown node:node "$WORKSPACE_DIR"
find "$CONFIG_DIR" -maxdepth 1 -not -path "$CONFIG_DIR" -exec chown node:node {} +
# Fix credentials/ recursively — docker exec runs as root and any
# CLI command (e.g. openclaw pairing approve) creates files as root
# inside this dir, making them unreadable by the gateway (node).
if [ -d "$CONFIG_DIR/credentials" ]; then
  chown -R node:node "$CONFIG_DIR/credentials"
fi

# ── Drop to node: seed config then exec the CMD ────────────────
exec su -s /bin/sh node -c '
  /app/scripts/setup-config.sh
  exec "$@"
' -- "$@"
