/**
 * enforcement/mutation.ts
 *
 * Mutation validation helper.
 *
 * Authority: docs/planning/schema-build-sheet.md (Core Build Rules §2)
 *            docs/architecture/data/schema-governance.md
 *            docs/api/api-conventions.md
 *
 * This module provides helpers for validating mutation inputs before they
 * reach the database. Key responsibilities:
 *
 *   - key format enforcement (governed regex)
 *   - priority range enforcement
 *   - blocked-reason requirement
 *   - updatedAt maintenance pattern reminder
 *
 * These helpers supplement (not replace) database-level CHECK constraints.
 * The database enforces the same rules structurally; these helpers provide
 * deterministic 400/422 responses before the DB round-trip.
 *
 * Implementation status: foundational helpers implemented; entity-specific
 * mutation validators are added alongside entity service layers.
 */

import {
  KEY_FORMAT_REGEX,
  KEY_MIN_LENGTH,
  KEY_MAX_LENGTH,
  PRIORITY_MIN,
  PRIORITY_MAX,
} from './vocabulary.js';

// ---------------------------------------------------------------------------
// Key format validation
// Authority: docs/architecture/data/schema-governance.md "Key Format Rule"
// ---------------------------------------------------------------------------

/**
 * Validate a Project V key value.
 * Returns null on success or an error message string on failure.
 */
export function validateKey(key: unknown): string | null {
  if (typeof key !== 'string') return 'key must be a string';
  if (key.length < KEY_MIN_LENGTH || key.length > KEY_MAX_LENGTH) {
    return `key must be between ${KEY_MIN_LENGTH} and ${KEY_MAX_LENGTH} characters`;
  }
  if (!KEY_FORMAT_REGEX.test(key)) {
    return 'key must match ^[a-z0-9]+(-[a-z0-9]+)*$ (lowercase letters, digits, single hyphens)';
  }
  return null;
}

// ---------------------------------------------------------------------------
// Priority range validation
// Authority: docs/architecture/data/controlled-vocabularies.md "Priority"
// ---------------------------------------------------------------------------

/**
 * Validate a priority value.
 * Returns null on success or an error message string on failure.
 */
export function validatePriority(priority: unknown): string | null {
  if (typeof priority !== 'number' || !Number.isInteger(priority)) {
    return 'priority must be an integer';
  }
  if (priority < PRIORITY_MIN || priority > PRIORITY_MAX) {
    return `priority must be between ${PRIORITY_MIN} and ${PRIORITY_MAX}`;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Non-empty string validation
// ---------------------------------------------------------------------------

/**
 * Validate that a required string field is non-empty after trimming.
 * Returns null on success or an error message string on failure.
 */
export function validateNonEmpty(field: string, value: unknown): string | null {
  if (typeof value !== 'string') return `${field} must be a string`;
  if (value.trim().length === 0) return `${field} must not be empty`;
  return null;
}

// ---------------------------------------------------------------------------
// Blocked state validation
// Authority: docs/planning/schema-build-sheet.md §4 WorkItem
// ---------------------------------------------------------------------------

/**
 * Validate that a blocked=true work item has a non-empty blockedReason.
 * Returns null on success or an error message string on failure.
 */
export function validateBlockedState(
  blocked: unknown,
  blockedReason: unknown
): string | null {
  if (blocked === true) {
    if (!blockedReason || (typeof blockedReason === 'string' && blockedReason.trim().length === 0)) {
      return 'blockedReason is required when blocked is true';
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// URL format validation
// Authority: docs/api/api-conventions.md (External Reference Validation Rule)
// ---------------------------------------------------------------------------

/**
 * Validate that a URL is non-empty and begins with https://.
 * Used for GitHubLink.url.
 * Returns null on success or an error message string on failure.
 */
export function validateHttpsUrl(url: unknown): string | null {
  if (typeof url !== 'string' || url.trim().length === 0) return 'url must be a non-empty string';
  if (!url.startsWith('https://')) return 'url must begin with https://';
  return null;
}

// ---------------------------------------------------------------------------
// updatedAt maintenance reminder
// ---------------------------------------------------------------------------
// There are no database triggers for updatedAt (by schema-governance rule).
// Every mutation that updates a row MUST include updatedAt: new Date() in
// the UPDATE statement within the same transaction as the governed write.
// This is not enforced here; it is a service-layer responsibility.
// See: docs/architecture/data/schema-governance.md "updatedAt Maintenance Rule"
