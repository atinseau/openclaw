import { resolveProvider, listProviders } from './router.ts'
import { forwardToOpenClaw } from './forwarder.ts'

const PORT = parseInt(process.env.PORT ?? '3001', 10)

// ---------------------------------------------------------------------------
// Request handler
// ---------------------------------------------------------------------------

async function handleWebhook(req: Request, providerName: string): Promise<Response> {
  const provider = resolveProvider(providerName)
  if (!provider) {
    return new Response(
      JSON.stringify({ error: `Unknown provider: ${providerName}`, available: listProviders() }),
      { status: 404, headers: { 'Content-Type': 'application/json' } },
    )
  }

  // Read raw body first — needed for HMAC verification before parsing
  const rawBody = await req.text()

  // Verify signature / authenticity
  const verified = await provider.verify(req, rawBody)
  if (!verified) {
    console.warn(`[${providerName}] signature verification failed`)
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // Parse payload
  let payload: unknown
  try {
    payload = JSON.parse(rawBody)
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // Transform to message
  const message = provider.toMessage(payload, req.headers)
  if (message === null) {
    // Provider explicitly ignores this event
    return new Response(JSON.stringify({ ok: true, ignored: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // Forward to OpenClaw
  try {
    await forwardToOpenClaw({
      message,
      name: providerName.charAt(0).toUpperCase() + providerName.slice(1),
      wakeMode: 'now',
      deliver: true,
      channel: 'last',
    })
    console.log(`[${providerName}] event forwarded to OpenClaw`)
  } catch (err) {
    console.error(`[${providerName}] failed to forward to OpenClaw:`, err)
    return new Response(JSON.stringify({ error: 'Failed to forward to OpenClaw' }), {
      status: 502,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
}

// ---------------------------------------------------------------------------
// HTTP server
// ---------------------------------------------------------------------------

const server = Bun.serve({
  port: PORT,

  async fetch(req) {
    const url = new URL(req.url)

    // Health check
    if (url.pathname === '/healthz') {
      return new Response(JSON.stringify({ ok: true, providers: listProviders() }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // Webhook routes: POST /webhooks/<provider> or POST /<provider>
    // Traefik may strip the /webhooks prefix when forwarding — handle both.
    const match = url.pathname.match(/^(?:\/webhooks)?\/([a-z0-9_-]+)$/)
    if (match && req.method === 'POST') {
      return handleWebhook(req, match[1])
    }

    return new Response(JSON.stringify({ error: 'Not found' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json' },
    })
  },

  error(err) {
    console.error('[server] unhandled error:', err)
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  },
})

console.log(`✅ webhook-proxy listening on port ${server.port}`)
console.log(`   providers: ${listProviders().join(', ')}`)
