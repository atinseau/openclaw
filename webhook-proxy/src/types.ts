/**
 * Contract that every webhook provider must implement.
 * To add a new provider, create a file in `providers/` and register it in `router.ts`.
 */
export interface WebhookProvider {
  /** Unique name used as the URL path segment: /webhooks/<name> */
  name: string

  /**
   * Verify the authenticity of the incoming request.
   * Return true if the request is legitimate, false to reject with 401.
   */
  verify(req: Request, rawBody: string): Promise<boolean>

  /**
   * Transform the parsed payload into a human-readable message for JARVIS.
   * Return null to silently ignore the event (e.g. unsupported event type).
   */
  toMessage(payload: unknown, headers: Headers): string | null
}

export interface OpenClawAgentPayload {
  message: string
  name: string
  wakeMode?: 'now' | 'next-heartbeat'
  deliver?: boolean
  channel?: string
}
