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
# docker exec and Coolify terminal run as root — any CLI command
# (pairing approve, agents add, etc.) creates files as root:root.
# We fix everything recursively on every boot to be safe.
echo "Fixing volume ownership …"
mkdir -p "$WORKSPACE_DIR"
chown -R node:node "$CONFIG_DIR"

# ── Drop to node: seed config then exec the CMD ────────────────
exec su -s /bin/sh node -c '
  /app/scripts/setup-config.sh
  exec "$@"
' -- "$@"
