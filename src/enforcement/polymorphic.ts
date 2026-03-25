/**
 * enforcement/polymorphic.ts
 *
 * Central polymorphic reference resolver.
 *
 * Authority: docs/architecture/data/polymorphic-reference-enforcement.md
 *            docs/planning/schema-build-sheet.md (Polymorphic reference convention)
 *
 * Tables that use entityType + entityId polymorphic references:
 *   Dependency, DecisionRecord, ReadinessEvaluation, EvidenceLink,
 *   Handoff, StatusHistory, AuditRun, GitHubLink
 *
 * The resolver must:
 *   1. Validate that entityType is allowed for the given table/context
 *   2. Look up the referenced row by entity type and id
 *   3. Verify the row belongs to the same projectId as the owning row
 *   4. Return a normalized resolution result
 *   5. Return the same error shape for cross-project and non-existent targets
 *      (no cross-project existence leakage)
 *
 * SPECIAL CASE: When entityType = 'project', the same-project check is:
 *   ownerRow.projectId === targetEntityId
 * The Project table has no projectId column. The resolver must not attempt to
 * read projectId from the resolved Project row.
 * See: docs/architecture/data/polymorphic-reference-enforcement.md §AuditRun
 *
 * Implementation status: scaffold with typed interfaces and allowed-type registry.
 * Full row-lookup implementations are added alongside entity service layers.
 */

import type { Tx } from '../db/transaction.js';

// ---------------------------------------------------------------------------
// Allowed entity types per polymorphic table/context
// Authority: docs/architecture/data/polymorphic-reference-enforcement.md
// ---------------------------------------------------------------------------

export const POLYMORPHIC_ALLOWED_TYPES = {
  dependency_source:      ['objective', 'initiative', 'work_item', 'handoff'],
  dependency_target:      ['objective', 'initiative', 'work_item', 'handoff'],
  decision_record:        ['objective', 'initiative', 'work_item', 'handoff'],
  readiness_evaluation:   ['objective', 'initiative', 'work_item', 'handoff'],
  evidence_link_source:   ['objective', 'initiative', 'work_item', 'handoff', 'decision_record', 'research_doc'],
  handoff_source:         ['objective', 'initiative', 'work_item'],
  status_history:         ['project', 'objective', 'initiative', 'work_item', 'handoff', 'decision_record', 'audit_run'],
  audit_run_target:       ['project', 'objective', 'initiative', 'work_item', 'handoff'],
  github_link_source:     ['objective', 'initiative', 'work_item', 'handoff', 'decision_record', 'research_doc', 'audit_run'],
} as const;

export type PolymorphicContext = keyof typeof POLYMORPHIC_ALLOWED_TYPES;

// ---------------------------------------------------------------------------
// Resolution result
// ---------------------------------------------------------------------------

export interface PolymorphicResolution {
  entityType: string;
  entityId: string;
  projectId: string;
  status?: string;
  isArchived?: boolean;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Check whether the given entityType is allowed for the given polymorphic context.
 * Returns true if allowed, false otherwise.
 */
export function isEntityTypeAllowed(context: PolymorphicContext, entityType: string): boolean {
  return (POLYMORPHIC_ALLOWED_TYPES[context] as readonly string[]).includes(entityType);
}

/**
 * Resolve a polymorphic reference and verify same-project ownership.
 *
 * Returns a PolymorphicResolution on success.
 * Returns null if the entity does not exist or belongs to another project.
 * Callers must not distinguish "not found" from "wrong project" in error responses.
 *
 * Handles the special 'project' entity type: same-project check is
 *   ownerProjectId === entityId  (Project has no projectId column).
 *
 * Implementation status: placeholder — table-level row lookups are added as
 * entity service layers are built.
 */
export async function resolvePolymorphicReference(
  _context: PolymorphicContext,
  _entityType: string,
  _entityId: string,
  _ownerProjectId: string,
  _tx?: Tx
): Promise<PolymorphicResolution | null> {
  // TODO: implement per entity type when service layers are added.
  throw new Error('resolvePolymorphicReference: not yet implemented for entityType: ' + _entityType);
}
