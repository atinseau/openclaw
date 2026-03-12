#!/bin/sh
# Connect to the running OpenClaw container as user "node".
# Usage: ./scripts/remote-shell.sh [command...]
#
# Examples:
#   ./scripts/remote-shell.sh                        # interactive shell
#   ./scripts/remote-shell.sh openclaw pairing list  # run a single command

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ENV_FILE="$SCRIPT_DIR/../.env"

if [ -f "$ENV_FILE" ]; then
  . "$ENV_FILE"
fi

REMOTE="${OPENCLAW_REMOTE_HOST:?Set OPENCLAW_REMOTE_HOST in .env}"
CONTAINER=$(ssh "$REMOTE" "sudo docker ps --format '{{.Names}}' | grep -i claw" 2>/dev/null | head -1)

if [ -z "$CONTAINER" ]; then
  echo "Error: no OpenClaw container found on remote host." >&2
  exit 1
fi

if [ $# -eq 0 ]; then
  exec ssh -t "$REMOTE" "sudo docker exec -it -u node '$CONTAINER' /bin/sh"
else
  exec ssh "$REMOTE" "sudo docker exec -u node '$CONTAINER' $*"
fi
