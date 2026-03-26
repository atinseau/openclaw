import type { WebhookProvider } from '../types.ts'

const SECRET = process.env.WEBHOOK_SECRET_GITHUB ?? ''

// ---------------------------------------------------------------------------
// HMAC-SHA256 signature verification
// ---------------------------------------------------------------------------

async function computeHmac(secret: string, body: string): Promise<string> {
  const encoder = new TextEncoder()
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign('HMAC', key, encoder.encode(body))
  const hex = Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')
  return `sha256=${hex}`
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false
  let result = 0
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i)
  }
  return result === 0
}

// ---------------------------------------------------------------------------
// Message formatters per GitHub event type
// ---------------------------------------------------------------------------

type Formatter = (payload: Record<string, unknown>) => string | null

const formatters: Record<string, Formatter> = {
  issues: (payload) => {
    const action = payload.action as string
    if (action !== 'opened') return null // only notify on new issues

    const issue = payload.issue as Record<string, unknown>
    const repo = (payload.repository as Record<string, unknown>).full_name as string
    const title = issue.title as string
    const author = (issue.user as Record<string, unknown>).login as string
    const url = issue.html_url as string
    const body = (issue.body as string | null) ?? '(no description)'

    return [
      `📋 New GitHub issue on **${repo}**`,
      `Title: ${title}`,
      `Author: ${author}`,
      `URL: ${url}`,
      `Description: ${body.slice(0, 300)}${body.length > 300 ? '…' : ''}`,
    ].join('\n')
  },

  pull_request: (payload) => {
    const action = payload.action as string
    if (!['opened', 'closed', 'reopened'].includes(action)) return null

    const pr = payload.pull_request as Record<string, unknown>
    const repo = (payload.repository as Record<string, unknown>).full_name as string
    const title = pr.title as string
    const author = (pr.user as Record<string, unknown>).login as string
    const url = pr.html_url as string
    const merged = pr.merged as boolean

    const actionLabel = action === 'closed' ? (merged ? 'merged' : 'closed') : action
    return [
      `🔀 Pull request **${actionLabel}** on **${repo}**`,
      `Title: ${title}`,
      `Author: ${author}`,
      `URL: ${url}`,
    ].join('\n')
  },

  push: (payload) => {
    const repo = (payload.repository as Record<string, unknown>).full_name as string
    const ref = payload.ref as string
    const branch = ref.replace('refs/heads/', '')
    const pusher = (payload.pusher as Record<string, unknown>).name as string
    const commits = (payload.commits as unknown[]).length

    return `🚀 Push on **${repo}** (${branch}) by ${pusher} — ${commits} commit(s)`
  },

  ping: () => {
    // GitHub sends a ping when the webhook is first configured — acknowledge silently
    return null
  },
}

// ---------------------------------------------------------------------------
// Provider implementation
// ---------------------------------------------------------------------------

export const githubProvider: WebhookProvider = {
  name: 'github',

  async verify(req: Request, rawBody: string): Promise<boolean> {
    if (!SECRET) {
      console.warn('[github] WEBHOOK_SECRET_GITHUB is not set — skipping signature check')
      return true
    }
    const signature = req.headers.get('x-hub-signature-256')
    if (!signature) return false

    const expected = await computeHmac(SECRET, rawBody)
    return timingSafeEqual(signature, expected)
  },

  toMessage(payload: unknown, headers: Headers): string | null {
    const event = headers.get('x-github-event') ?? 'unknown'
    const formatter = formatters[event]

    if (!formatter) {
      console.log(`[github] unhandled event type: ${event}`)
      return null
    }

    return formatter(payload as Record<string, unknown>)
  },
}
