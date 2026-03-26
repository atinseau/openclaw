# webhook-proxy

Generic webhook receiver for OpenClaw. Validates incoming webhooks from external services,
transforms the payloads into human-readable messages, and forwards them to OpenClaw's
`/hooks/agent` endpoint.

## Architecture

```
External service (GitHub, Stripe, etc.)
        │
        │  POST /webhooks/<provider>
        ▼
  webhook-proxy  (this service)
        │  validates signature
        │  formats message
        │  POST /hooks/agent
        ▼
  openclaw-gateway  (internal Docker network)
        │
        ▼
  JARVIS notification
```

## Adding a new provider

1. Create `src/providers/<name>.ts` implementing the `WebhookProvider` interface:

```ts
import type { WebhookProvider } from '../types.ts'

export const myProvider: WebhookProvider = {
  name: 'myprovider',

  async verify(req, rawBody) {
    // Validate the request (HMAC, token header, etc.)
    return true
  },

  toMessage(payload, headers) {
    // Return a human-readable string, or null to ignore the event
    return `Something happened: ${JSON.stringify(payload)}`
  },
}
```

2. Register it in `src/router.ts`:

```ts
import { myProvider } from './providers/myprovider.ts'

const providers: WebhookProvider[] = [
  githubProvider,
  myProvider, // ← add here
]
```

3. Add the secret env var in `.env.example` and `docker-compose.yml`.

That's it. No other files to touch.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/healthz` | Health check — returns `{ ok: true, providers: [...] }` |
| `POST` | `/webhooks/<provider>` | Receive a webhook from a registered provider |

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `PORT` | No (default: `3001`) | Port to listen on |
| `OPENCLAW_INTERNAL_URL` | Yes | Internal URL of the OpenClaw gateway |
| `OPENCLAW_HOOKS_TOKEN` | Yes | Must match `hooks.token` in `openclaw.json` |
| `WEBHOOK_SECRET_GITHUB` | For GitHub | GitHub App webhook secret |

## GitHub App setup

1. Go to `github.com/settings/apps` → **New GitHub App**
2. Set **Webhook URL** to `https://your-domain.com/webhooks/github`
3. Set **Webhook secret** to the value of `WEBHOOK_SECRET_GITHUB`
4. Under **Permissions**, set **Issues → Read-only**
5. Under **Subscribe to events**, check **Issues** (and any others you want)
6. Install the app on your account → **All repositories**

Supported GitHub events: `issues`, `pull_request`, `push`, `ping`.
