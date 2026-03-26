# CLAUDE.md

Guidance for AI coding agents working on this repository.

## Repo identity

Thin deployment overlay on `ghcr.io/openclaw/openclaw:latest`. This is NOT the upstream source. We only own what differs from the upstream image.

### Files you can edit

| File / Dir | What it does |
|---|---|
| `Dockerfile` | Extends upstream image — brew packages, skills, scripts, config |
| `docker-compose.yml` | Coolify-ready compose — volumes, browserless sidecar, healthcheck |
| `config/openclaw.json` | Seed config — deep-merged into live config on every boot |
| `scripts/entrypoint.sh` | Root entrypoint — fixes volume ownership, drops to `node` |
| `scripts/setup-config.sh` | Seed logic — placeholder substitution, first-boot vs deep-merge |
| `scripts/remote-shell.sh` | SSH into the live container (reads `OPENCLAW_REMOTE_HOST` from `.env`) |
| `skills/` | Custom skills → `/app/custom-skills/` inside the container |
| `avatars/` | Agent avatars → seeded into workspace volume on first boot |

### Files you must NOT edit

- `openclaw-repo/` — git-ignored upstream checkout, read-only reference
- `.env` — contains live credentials, never commit

## Deployment

`git push` → Coolify webhook → rebuild from `Dockerfile` → redeploy with volumes intact.

Pin a version: change `FROM ghcr.io/openclaw/openclaw:latest` to a specific tag (e.g. `:2025.7.15`).

## Dockerfile structure

The image layers in order:
1. `FROM ghcr.io/openclaw/openclaw:latest`
2. **apt packages** — `build-essential` (required by Homebrew)
3. **Homebrew** — installed as `node` user at `/home/linuxbrew/.linuxbrew/`
4. **brew packages** — `gh`, `jq`, and any future tools
5. **Custom skills** — `COPY skills/ /app/custom-skills/`
6. **Startup optimization** — `NODE_COMPILE_CACHE`, `OPENCLAW_NO_RESPAWN`
7. **Avatars + seed config + entrypoint** — changes here invalidate fewer layers

When adding packages: use `brew install <pkg>` (add a `RUN` after the existing `brew install` lines). Only use apt for system-level dependencies that brew can't provide.

## Environment variables

Required:
- `OPENCLAW_GATEWAY_TOKEN` — auth token for Control UI + API
- `OPENCLAW_DOMAIN` — public domain; entrypoint exits if missing

Optional:
- `GH_TOKEN` — GitHub PAT for `gh` CLI
- `GEMINI_API_KEY` — memory search embeddings
- `BROWSERLESS_TOKEN` — Browserless auth (default: `openclaw-local`)
- `BROWSERLESS_CONCURRENT` / `BROWSERLESS_QUEUED` / `BROWSERLESS_TIMEOUT` — concurrency limits
- `CLAUDE_AI_SESSION_KEY`, `CLAUDE_WEB_SESSION_KEY`, `CLAUDE_WEB_COOKIE` — Claude provider creds
- `OPENCLAW_ALLOW_INSECURE_PRIVATE_WS` — allow `ws://` on private networks

## Browserless sidecar

Separate `browserless` service in `docker-compose.yml` (Chromium CDP). Gateway connects via `BROWSERLESS_CDP_URL`. Must be running for browser-based tools.

## Seed config mechanics

`config/openclaw.json` uses placeholders `__OPENCLAW_DOMAIN__` and `__BROWSERLESS_CDP_URL__`.

On boot, `setup-config.sh`:
1. Resolves placeholders from env vars
2. First boot → writes resolved config to persistent volume
3. Subsequent boots → `jq -s '.[0] * .[1]'` deep-merges seed into existing (live changes preserved)
4. Validates with `openclaw config validate`, runs `doctor --fix` if invalid

## Custom skills

Path: `skills/<skill-name>/SKILL.md`. Mounted at `/app/custom-skills/`, discovered via `skills.load.extraDirs`.

Do NOT reuse names from upstream `/app/skills/`.

| Skill | Purpose |
|---|---|
| `browser-automation` | CDP browser tool reference — actions, snapshots, patterns |
| `web-scraping` | `web_fetch` vs `browser` decision framework |
| `container-tools` | Documents custom tools installed in the container |

## Ports & volumes

| Port | Service |
|---|---|
| 18789 | Gateway — API + Web UI |
| 18790 | Bridge — ACP / IDE integrations |

| Volume | Container path |
|---|---|
| `openclaw-config` | `/home/node/.openclaw` |
| `openclaw-workspace` | `/home/node/.openclaw/workspace` |

Healthcheck: `GET /healthz` (liveness), `GET /readyz` (readiness) — no auth.

## Live instance access

```sh
./scripts/remote-shell.sh                        # interactive shell
./scripts/remote-shell.sh openclaw pairing list  # single command
./scripts/remote-shell.sh openclaw skills list
./scripts/remote-shell.sh cat /home/node/.openclaw/openclaw.json
```

Requires `OPENCLAW_REMOTE_HOST` in `.env`.

### Safety rules — MANDATORY

- **Read-only by default.** Use `remote-shell.sh` freely for inspection.
- **ASK before ANY write/destructive action:** modifying config, deleting volumes, restarting services, removing pairings/skills/workspaces.
- **Never assume "it's fine to try."** The instance has active users and live pairings.
