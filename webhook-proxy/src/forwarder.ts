import type { OpenClawAgentPayload } from './types.ts'

const OPENCLAW_URL = process.env.OPENCLAW_INTERNAL_URL ?? 'http://openclaw-gateway:18789'
const OPENCLAW_TOKEN = process.env.OPENCLAW_HOOKS_TOKEN ?? ''

/**
 * Forward a formatted message to OpenClaw's /hooks/agent endpoint.
 * This is the single exit point for all providers.
 */
export async function forwardToOpenClaw(payload: OpenClawAgentPayload): Promise<void> {
  const url = `${OPENCLAW_URL}/hooks/agent`

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${OPENCLAW_TOKEN}`,
    },
    body: JSON.stringify(payload),
  })

  if (!res.ok) {
    const body = await res.text().catch(() => '(empty)')
    throw new Error(`OpenClaw responded with ${res.status}: ${body}`)
  }
}
