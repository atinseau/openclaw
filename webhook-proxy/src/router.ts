import type { WebhookProvider } from './types.ts'
import { githubProvider } from './providers/github.ts'

/**
 * Registry of all webhook providers.
 * To add a new provider: create a file in `providers/`, implement WebhookProvider,
 * and add it to this array. Nothing else to change.
 */
const providers: WebhookProvider[] = [
  githubProvider,
  // stripeProvider,   // coming soon
  // linearProvider,   // coming soon
]

const providerMap = new Map(providers.map((p) => [p.name, p]))

export function resolveProvider(name: string): WebhookProvider | undefined {
  return providerMap.get(name)
}

export function listProviders(): string[] {
  return providers.map((p) => p.name)
}
