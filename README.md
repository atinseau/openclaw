# OpenClaw — Custom Deployment for Coolify

Self-hosted [OpenClaw](https://github.com/openclaw/openclaw) gateway, built as a thin overlay on top of the official upstream image. Push to redeploy; volumes keep your data across upgrades.

## Architecture

```
┌─────────────────────────────────┐        ┌────────────────────────────┐
│  This repo                      │        │  Upstream (GitHub CI)      │
│                                 │        │                            │
│  Dockerfile                     │─FROM──▶│  ghcr.io/openclaw/openclaw │
│   + your apt packages           │        │  :latest (or pinned tag)   │
│   + your scripts / skills       │        │                            │
│                                 │        └────────────────────────────┘
│  docker-compose.yml             │
│   + named volumes (persistent)  │
│   + env vars from Coolify       │
└────────────┬────────────────────┘
             │ git push → Coolify webhook
             ▼
      ┌──────────────┐
      │   Coolify     │  reverse proxy + TLS
      │   rebuild     │  named volumes intact
      │   redeploy    │  healthcheck → live
      └──────────────┘
```

**Key point:** you depend on the *published image*, not upstream's Dockerfile or docker-compose. When OpenClaw updates their image, you get the changes on the next rebuild. Your customizations (packages, skills, scripts) layer on top and persist independently.

## Files

| File                 | Purpose                                                      |
| -------------------- | ------------------------------------------------------------ |
| `Dockerfile`         | Extends `ghcr.io/openclaw/openclaw:latest` with your extras  |
| `docker-compose.yml` | Coolify-ready compose with named volumes and healthcheck      |
| `.env.example`       | Template for environment variables                            |
| `.gitignore`         | Ignores `.env` and `openclaw-repo/`                           |
| `openclaw-repo/`     | (optional) Upstream repo checkout for reference, git-ignored  |

## Ports

| Port    | Service                          |
| ------- | -------------------------------- |
| `18789` | Gateway — API + Web UI (Control) |
| `18790` | Bridge — ACP / IDE integrations  |

## Volumes (persistent across redeploys)

| Volume              | Container path                  | Contents                                       |
| ------------------- | ------------------------------- | ---------------------------------------------- |
| `openclaw-config`   | `/home/node/.openclaw`          | Config, identity, agent sessions, credentials  |
| `openclaw-workspace`| `/home/node/.openclaw/workspace`| Agent working files                            |

## Setup on Coolify

### 1. Create your repo

Clone or fork this repo to your Git provider (GitHub, Gitea, Forgejo, etc.).

### 2. Add resource in Coolify

1. **New Resource → Docker Compose**
2. **Source:** your Git repository
3. **Compose file path:** `docker-compose.yml`
4. **Branch:** `main` (or whichever you use)

### 3. Configure environment variables

In Coolify UI → your resource → **Environment Variables**, add:

```
OPENCLAW_GATEWAY_TOKEN=<your-token>
```

Generate a token:

```bash
openssl rand -hex 32
```

See `.env.example` for all available variables.

### 4. Configure domain

In Coolify → your resource → **Settings**:

- Set your domain (e.g. `openclaw.yourdomain.com`)
- Map it to port **18789** of the `openclaw-gateway` service
- Coolify handles TLS (Let's Encrypt) and reverse proxy automatically

### 5. Deploy

Hit **Deploy** (or just `git push` — Coolify auto-deploys via webhook).

### 6. Access the UI

1. Open `https://openclaw.yourdomain.com/`
2. Paste your `OPENCLAW_GATEWAY_TOKEN` in Settings
3. Configure your AI providers (API keys for OpenAI, Anthropic, etc.)

## Customizing the image

Edit `Dockerfile` to add anything you need:

```dockerfile
USER root

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      python3 \
      ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Add custom skills
COPY skills/ /app/skills/

USER node
```

Push → Coolify rebuilds → your packages are installed on top of the latest OpenClaw.

## Staying up to date

Your `Dockerfile` starts with `FROM ghcr.io/openclaw/openclaw:latest`. The upstream image is rebuilt on every push to `main` and on every tagged release.

| Strategy               | How                                                        | Automatic? |
| ---------------------- | ---------------------------------------------------------- | ---------- |
| **Manual redeploy**    | Click "Redeploy" in Coolify (pulls fresh `:latest`)        | No         |
| **Scheduled rebuild**  | Coolify cron / scheduled deployment (e.g. nightly at 3 AM) | Yes        |
| **Pin a version**      | Change `FROM` to `:2025.7.15` and bump manually            | No         |

> **Tip:** Use `:latest` for convenience or pin to a specific tag (e.g. `:2025.7.15`) for stability. Tagged releases follow the format `YYYY.M.D`.

## Healthcheck

The gateway exposes probe endpoints (no auth needed):

- `GET /healthz` — liveness (is the process up?)
- `GET /readyz` — readiness (are channels connected?)

The compose file includes a Docker healthcheck that pings `/healthz` every 30 seconds.

## Troubleshooting

### "unauthorized" or "pairing required" in the UI

Your `OPENCLAW_GATEWAY_TOKEN` is missing or wrong. Check the environment variable in Coolify.

### Container starts but UI is unreachable

Make sure the gateway binds to `lan` (0.0.0.0), not `loopback`. The compose command already sets `--bind lan`. Also verify Coolify's domain/proxy is mapping to port `18789`.

### Data lost after redeploy

Named volumes (`openclaw-config`, `openclaw-workspace`) survive container replacement. If you accidentally deleted them, they're gone — consider setting up volume backups in Coolify.

### Build fails with OOM

The upstream image is pre-built; your overlay build should be lightweight. If you're installing large packages and the build gets killed, increase Docker's memory limit on your Coolify server.

## License

This deployment wrapper is for personal use. OpenClaw itself is [MIT licensed](https://github.com/openclaw/openclaw/blob/main/LICENSE).