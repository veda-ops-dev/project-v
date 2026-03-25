/**
 * lib/cursor.ts
 *
 * Cursor encoding/decoding for Project V cursor-based pagination.
 *
 * Authority: docs/api/api-conventions.md (Pagination Rule, Cursor format rule)
 *
 * ── CONTRACT ─────────────────────────────────────────────────────────────────
 *
 * Cursor format (internal, stable):
 *   base64url( JSON({ u: <ISO-8601 updatedAt>, i: <uuid id> }) )
 *
 *   Keys are intentionally short ('u', 'i') and must not be changed without
 *   a breaking-change review. Changing key names silently invalidates all
 *   in-flight cursors held by callers.
 *
 * Cursor behavior rules (from api-conventions.md):
 *   - Clients must treat cursor values as opaque strings.
 *   - A malformed cursor must fail with 400 Bad Request (caller responsibility).
 *   - A cursor is valid only for the ordering defined by its route family.
 *   - offset / page parameters are not allowed on list endpoints.
 *   - nextCursor is null (not omitted) when there are no more results.
 *
 * Ordering rule that this cursor encodes:
 *   ORDER BY "updatedAt" DESC, id ASC
 *
 *   The row-value comparison used in queries is:
 *     ("updatedAt", id) < (cursorUpdatedAt, cursorId)
 *   This correctly continues after the last seen row in updatedAt-desc order
 *   because the comparison respects the DESC direction for updatedAt and
 *   ASC for id as a stable tie-breaker.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 */

export interface CursorPayload {
  updatedAt: Date;
  id: string;
}

/**
 * Encode a cursor payload into an opaque base64url string.
 *
 * Internal key names ('u', 'i') are stable contract fields.
 * Do not rename without a breaking-change review.
 */
export function encodeCursor(payload: CursorPayload): string {
  const raw = JSON.stringify({
    u: payload.updatedAt.toISOString(),
    i: payload.id,
  });
  return Buffer.from(raw).toString('base64url');
}

/**
 * Decode a cursor string. Returns null if malformed or structurally invalid.
 *
 * Callers must treat null as a signal to return 400 Bad Request.
 */
export function decodeCursor(cursor: string): CursorPayload | null {
  try {
    const raw = Buffer.from(cursor, 'base64url').toString('utf8');
    const parsed = JSON.parse(raw) as { u?: unknown; i?: unknown };
    if (typeof parsed.u !== 'string' || typeof parsed.i !== 'string') return null;
    const updatedAt = new Date(parsed.u);
    if (isNaN(updatedAt.getTime())) return null;
    return { updatedAt, id: parsed.i };
  } catch {
    return null;
  }
}
