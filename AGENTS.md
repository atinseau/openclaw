# AGENTS.md

This file provides guidance to AI coding agents (Claude Code, GitHub Copilot, etc.) when working with code in this repository.

## What this repo is

A thin deployment overlay on top of the official `ghcr.io/openclaw/openclaw` image. It is **not** the upstream OpenClaw source — that lives at `openclaw-repo/` (git-ignored, for local reference only). This repo only contains what differs from the upstream image:

- `Dockerfile` — extends the upstream image with custom packages, skills, and scripts
- `docker-compose.yml` — Coolify-ready compose (named volumes, browserless sidecar, healthcheck)
- `config/openclaw.json` — seed config (copied to the persistent volume on first boot)
- `scripts/entrypoint.sh` — fixes volume ownership as root, then drops to `node` user
- `scripts/setup-config.sh` — seeds `openclaw.json` if absent on the persistent volume
- `skills/` — custom skills mounted at `/app/custom-skills/` inside the container
- `.env.example` — all supported environment variables with descriptions

## Deployment workflow

Deployments are triggered by git push. Coolify picks up the webhook, rebuilds the image from `Dockerfile`, and redeploys with volumes intact.

To update to a newer upstream OpenClaw image: just redeploy (`:latest` is always pulled on rebuild). To pin a version, change the `FROM` line in `Dockerfile` to a specific tag (e.g. `FROM ghcr.io/openclaw/openclaw:2025.7.15`).

## Key environment variables

Required:
- `OPENCLAW_GATEWAY_TOKEN` — auth token for the Control UI and API
- `OPENCLAW_DOMAIN` — public domain (e.g. `openclaw.example.com`); also required at runtime by the entrypoint

Optional (pass-through to the container):
- `BROWSERLESS_TOKEN` — auth token for the Browserless CDP endpoint (default: `openclaw-local`)
- `BROWSERLESS_CONCURRENT`, `BROWSERLESS_QUEUED`, `BROWSERLESS_TIMEOUT` — Browserless concurrency limits (defaults: 2 / 5 / 120s)
- `CLAUDE_AI_SESSION_KEY`, `CLAUDE_WEB_SESSION_KEY`, `CLAUDE_WEB_COOKIE` — Claude provider credentials
- `OPENCLAW_ALLOW_INSECURE_PRIVATE_WS` — allow `ws://` targets on private networks

## Browserless sidecar

`docker-compose.yml` includes a **separate `browserless` service** (Chromium CDP) alongside `openclaw-gateway`. The gateway connects to it via `BROWSERLESS_CDP_URL`. The sidecar is not part of the OpenClaw image — it runs as a distinct container and must be running for browser-based tools to work.

Custom packages installed in the OpenClaw image (via `Dockerfile`): `jq`.

## Seed config mechanics

`config/openclaw.json` is copied into the image at `/app/config/openclaw.json`. At every boot, `setup-config.sh`:

1. Substitutes `__OPENCLAW_DOMAIN__` and `__BROWSERLESS_CDP_URL__` placeholders from environment variables.
2. **First boot** — writes the resolved seed config to the persistent volume (`/home/node/.openclaw/openclaw.json`).
3. **Subsequent boots** — deep-merges the seed config into the existing live config using `jq` (so manual live changes are preserved for keys not in the seed).
4. Runs `openclaw doctor --fix` to validate and auto-repair the schema.

## Custom skills

Skills live in `skills/<skill-name>/SKILL.md` (and any supporting files). They are mounted at `/app/custom-skills/` and discovered via `skills.load.extraDirs` in the seed config. Skill directories should not conflict with names in the upstream `/app/skills/` directory.

Current custom skills:

| Skill | Description |
|---|---|
| `browser-automation` | Full reference for the Browserless/Chromium CDP browser tool — actions, snapshot types, workflow patterns, limitations |
| `web-scraping` | Decision framework for choosing between `web_fetch` and `browser` — includes known cases requiring a browser |
| `container-tools` | Documents custom tools installed in the container (currently: `jq`) |

## Ports

| Port  | Service                                 |
|-------|-----------------------------------------|
| 18789 | Gateway — API + Web UI (Control Panel)  |
| 18790 | Bridge — ACP / IDE integrations         |

## Volumes

Both volumes persist across container replacements and image upgrades:

| Volume               | Container path                   |
|----------------------|----------------------------------|
| `openclaw-config`    | `/home/node/.openclaw`           |
| `openclaw-workspace` | `/home/node/.openclaw/workspace` |

## Healthcheck endpoints (no auth)

- `GET /healthz` — liveness
- `GET /readyz` — readiness

## Interacting with the live OpenClaw instance

Use `scripts/remote-shell.sh` to run commands inside the container on the remote host. Requires `OPENCLAW_REMOTE_HOST` to be set in `.env`.

```sh
# Interactive shell
./scripts/remote-shell.sh

# Run a single OpenClaw CLI command
./scripts/remote-shell.sh openclaw pairing list
./scripts/remote-shell.sh openclaw skills list
```

When you need to inspect live state (config, logs, skills, pairings) to answer a question or debug an issue, use this script rather than guessing from local files.

**IMPORTANT — safety rules for the live instance:**

- **Read-only by default.** Treat the live instance as production. Use `remote-shell.sh` freely for inspection (`openclaw skills list`, `openclaw pairing list`, reading config/logs, etc.).
- **Always ask before any write or destructive action.** This includes — but is not limited to:
  - Modifying, resetting, or deleting config (`/home/node/.openclaw/openclaw.json`)
  - Deleting or recreating Docker volumes
  - Restarting or stopping the container/services
  - Removing pairings, skills, or workspaces
  - Running any command that cannot be trivially undone
- **Never assume "it's fine to try".** The instance may have active users or live pairings. When in doubt, describe what you intend to do and wait for explicit confirmation before executing.
