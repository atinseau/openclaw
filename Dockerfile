# Custom OpenClaw image — overlay on top of the official upstream release.
# This keeps us on the latest version while letting us add our own packages,
# scripts, skills, and configuration that persist across upgrades.
#
# The upstream image already contains:
#   - Node 22 (bookworm)
#   - Built OpenClaw gateway + CLI (dist/, node_modules/, openclaw.mjs)
#   - playwright-core (used to connect to remote CDP endpoints)
#   - pnpm, git, curl, openssl, procps
#   - Non-root user "node" (uid 1000)
#   - CMD: node openclaw.mjs gateway --allow-unconfigured
#
# Browser note:
#   playwright-core is already bundled in the upstream image. When using a
#   remote CDP provider (Browserless), playwright-core connects over CDP
#   without needing a local Chromium binary. No extra Playwright install
#   is required.
#
# To pin a specific version instead of following latest:
#   FROM ghcr.io/openclaw/openclaw:2025.7.15
FROM ghcr.io/openclaw/openclaw:latest

# Switch to root to install system packages
USER root

# ── Custom system packages ──────────────────────────────────────
# Add any tools your skills or workflows need.
# Uncomment or extend as needed.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      jq \
      # python3 \
      # python3-pip \
      # ffmpeg \
      # wget \
    && rm -rf /var/lib/apt/lists/*

# ── Custom skills ───────────────────────────────────────────────
# Kept separate from bundled skills (/app/skills/) to avoid conflicts.
# Discovered via skills.load.extraDirs in config/openclaw.json.
COPY --chown=node:node skills/ /app/custom-skills/

# ── Startup optimization ────────────────────────────────────────
# Cache compiled bytecode so repeated CLI runs skip recompilation.
# Skip the self-respawn dance to avoid double-startup overhead.
ENV NODE_COMPILE_CACHE=/var/tmp/openclaw-compile-cache
ENV OPENCLAW_NO_RESPAWN=1
RUN mkdir -p /var/tmp/openclaw-compile-cache && chown node:node /var/tmp/openclaw-compile-cache

# ── Avatars ─────────────────────────────────────────────────────
# Baked into the image; setup-config.sh seeds them into the
# persistent workspace volume on first boot.
COPY --chown=node:node avatars/ /app/avatars/

# ── Seed config + entrypoint ────────────────────────────────────
# The seed config provides sane defaults for running behind a reverse
# proxy (Coolify/Traefik/Caddy). On first boot the entrypoint copies
# it to the persistent volume if no openclaw.json exists yet.
COPY --chown=node:node config/openclaw.json /app/config/openclaw.json
COPY --chown=node:node scripts/setup-config.sh /app/scripts/setup-config.sh
COPY --chown=root:root scripts/entrypoint.sh /app/scripts/entrypoint.sh
RUN chmod 755 /app/scripts/entrypoint.sh /app/scripts/setup-config.sh

# ── Custom scripts / config ─────────────────────────────────────
# COPY scripts/ /app/custom-scripts/

# Entrypoint runs as root to fix volume permissions, then drops to
# the "node" user before executing the CMD.
ENTRYPOINT ["/app/scripts/entrypoint.sh"]
