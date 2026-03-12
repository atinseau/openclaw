#!/bin/sh
set -e

CONFIG_DIR="/home/node/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"
SEED_FILE="/app/config/openclaw.json"
WORKSPACE_DIR="$CONFIG_DIR/workspace"

# ── Require OPENCLAW_DOMAIN ─────────────────────────────────────
if [ -z "$OPENCLAW_DOMAIN" ]; then
  echo "ERROR: OPENCLAW_DOMAIN is required (e.g. openclaw.example.com)"
  echo "Set it in Coolify environment variables and redeploy."
  exit 1
fi

# ── Fix volume ownership ────────────────────────────────────────
# Docker creates named volumes as root. We must fix ownership on
# every boot because either volume may have been freshly created.
# The workspace volume is mounted *inside* the config volume, so
# they are separate mount points — chown -R on the parent does NOT
# cross into the child mount. We handle them explicitly.
echo "Fixing volume ownership …"
chown node:node "$CONFIG_DIR"
# Fix workspace mount separately (it's a different volume)
mkdir -p "$WORKSPACE_DIR"
chown node:node "$WORKSPACE_DIR"

# ── Resolve seed config ─────────────────────────────────────────
RESOLVED_SEED=$(sed "s|__OPENCLAW_DOMAIN__|${OPENCLAW_DOMAIN}|g" "$SEED_FILE")

# ── Seed / merge config ─────────────────────────────────────────
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

# ── Ensure config file is owned by node ─────────────────────────
# The file was written by root (PID 1), so we must fix ownership
# explicitly. Also fix any other files that may exist at the top
# level of the config dir (identity files, sessions, etc.) without
# recursing into the workspace mount point.
chown node:node "$CONFIG_FILE"
# chown top-level files only (not recursive into workspace mount)
find "$CONFIG_DIR" -maxdepth 1 -not -path "$CONFIG_DIR" -exec chown node:node {} +

echo "Config ready — launching gateway as user 'node' …"

# ── Drop privileges and exec the CMD ────────────────────────────
exec su -s /bin/sh node -c '"$0" "$@"' -- "$@"
