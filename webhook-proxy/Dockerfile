# webhook-proxy — Bun-based generic webhook forwarder
# Receives webhooks from external services, validates them,
# and forwards formatted messages to OpenClaw's /hooks/agent endpoint.

FROM oven/bun:1-alpine AS base
WORKDIR /app

# ── Install dependencies ────────────────────────────────────────
FROM base AS deps
COPY package.json bun.lockb* ./
RUN bun install --frozen-lockfile 2>/dev/null || bun install

# ── Final image ─────────────────────────────────────────────────
FROM base AS runner
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Non-root user (bun image already has user "bun" with uid 1000)
USER bun

EXPOSE 3001

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3001/healthz || exit 1

CMD ["bun", "run", "src/index.ts"]
