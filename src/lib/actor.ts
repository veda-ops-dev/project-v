/**
 * lib/actor.ts
 *
 * Actor resolution for status history writes.
 *
 * Authority: docs/api/api-conventions.md (Actor Rule)
 *
 * The Actor Rule states: where a route writes a StatusHistory row, the actor
 * field is server-resolved from the authenticated request context. Callers
 * must not supply actor in the request body.
 *
 * Current status: placeholder implementation.
 *   The system has no auth layer yet. resolveActor returns 'system' until
 *   a real identity context is available.
 *
 * Integration point: when auth is added, replace the body of resolveActor
 * to derive the actor from the request context (e.g. JWT subject, API key
 * identity, or session user id). Nothing else in the codebase needs to change
 * — all StatusHistory writes go through this single call site.
 *
 * Do NOT spread actor logic into service methods directly.
 * Do NOT accept actor from callers.
 */

/**
 * Resolve the actor identifier for a StatusHistory write.
 *
 * Returns the authenticated identity when auth is available.
 * Returns 'system' as a placeholder until auth is implemented.
 *
 * The request context parameter is typed loosely so this function can accept
 * a Fastify request or any context object — keeping the signature stable
 * for the auth integration without requiring a full type overhaul.
 */
export function resolveActor(_requestContext?: unknown): string {
  // TODO: extract from authenticated request context when auth is added.
  // Pattern: return (ctx as FastifyRequest).user?.id ?? 'system';
  return 'system';
}
