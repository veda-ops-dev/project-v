/**
 * enforcement/scope.ts
 *
 * Project scope enforcement helper.
 *
 * Authority: docs/architecture/core/multi-project-doctrine.md
 *            docs/architecture/core/system-invariants.md §2
 *            docs/planning/schema-build-sheet.md (Same-project validation convention)
 *
 * This module provides shared helpers for enforcing project-scope invariants:
 *
 *   - same-project ownership checks for cross-entity references
 *   - archived-parent guard (prevents new children under archived parents)
 *   - project existence and status lookup
 *
 * IMPORTANT: Cross-project reads must behave as "unavailable", not "forbidden",
 * to avoid cross-project existence leakage. Do not return different error messages
 * for "row exists in another project" vs "row does not exist at all".
 *
 * Implementation status: scaffold with typed interfaces.
 * Full query implementations will be added alongside entity service layers.
 */

import type { Tx } from '../db/transaction.js';
import { db } from '../db/client.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ProjectRecord {
  id: string;
  status: string;
}

export interface ProjectScopedRecord {
  id: string;
  projectId: string;
  status?: string;
}

// ---------------------------------------------------------------------------
// Project lookup
// ---------------------------------------------------------------------------

/**
 * Load a project by ID. Returns null if not found.
 * Used to verify a project exists and inspect its status before creating children.
 */
export async function loadProject(
  projectId: string,
  tx?: Tx
): Promise<ProjectRecord | null> {
  const sql = tx ?? db;
  const rows = await sql<ProjectRecord[]>`
    SELECT id, status
    FROM app.project
    WHERE id = ${projectId}
  `;
  return rows[0] ?? null;
}

// ---------------------------------------------------------------------------
// Same-project enforcement
// ---------------------------------------------------------------------------

/**
 * Verify that a referenced row exists and belongs to the given projectId.
 *
 * Returns the referenced row on success.
 * Returns null if the row does not exist OR belongs to another project.
 *
 * Callers must not distinguish between "not found" and "wrong project" in their
 * error responses. Returning the same "unavailable" shape for both cases prevents
 * cross-project existence leakage.
 *
 * Implementation status: placeholder — concrete table queries are added per entity
 * family as those service layers are built.
 */
export async function verifyProjectOwnership(
  _table: string,
  _rowId: string,
  _projectId: string,
  _tx?: Tx
): Promise<ProjectScopedRecord | null> {
  // TODO: implement per-table lookup when entity service layers are added.
  // Pattern: SELECT id, "projectId" FROM app.<table> WHERE id = $1 AND "projectId" = $2
  throw new Error('verifyProjectOwnership: not yet implemented for table: ' + _table);
}

// ---------------------------------------------------------------------------
// Archived-parent guard
// ---------------------------------------------------------------------------

/**
 * Verify that the given project is not archived.
 * Returns true if the project is active or deferred (creation allowed).
 * Returns false if the project is archived (creation must be rejected).
 *
 * Authority: docs/planning/schema-build-sheet.md (Archived-parent hook)
 */
export async function isProjectOpenForChildren(
  projectId: string,
  tx?: Tx
): Promise<boolean> {
  const project = await loadProject(projectId, tx);
  if (!project) return false;
  return project.status !== 'archived';
}

/**
 * Verify that a parent entity (objective or initiative) is not archived.
 * Returns true if the parent can accept new children.
 * Returns false if archived (creation must be rejected).
 *
 * Implementation status: placeholder — resolved per-table when entity layers arrive.
 */
export async function isParentOpenForChildren(
  _table: string,
  _parentId: string,
  _projectId: string,
  _tx?: Tx
): Promise<boolean> {
  // TODO: implement per-table when entity service layers are added.
  // Pattern: SELECT status FROM app.<table> WHERE id = $1 AND "projectId" = $2
  throw new Error('isParentOpenForChildren: not yet implemented for table: ' + _table);
}
