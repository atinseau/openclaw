# Custom OpenClaw image — overlay on top of the official upstream release.
# This keeps us on the latest version while letting us add our own packages,
# scripts, skills, and configuration that persist across upgrades.
#
# The upstream image already contains:
#   - Node 22 (bookworm)
#   - Built OpenClaw gateway + CLI (dist/, node_modules/, openclaw.mjs)
#   - pnpm, git, curl, openssl, procps
#   - Non-root user "node" (uid 1000)
#   - CMD: node openclaw.mjs gateway --allow-unconfigured
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

# ── Custom skills / scripts / config ────────────────────────────
# COPY skills/ /app/skills/
# COPY scripts/ /app/custom-scripts/

# ── Back to non-root for runtime (security) ─────────────────────
USER node
