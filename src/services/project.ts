/**
 * services/project.ts
 *
 * Project service — owns all Project query, validation, and mutation logic.
 *
 * Authority: docs/api/projects-api.md
 *            docs/architecture/data/schema-specification.md §1 Project
 *            docs/architecture/data/status-transitions.md (Project transitions)
 *            docs/api/api-conventions.md (Pagination, Transaction, Error Code rules)
 *
 * Ordering rule: updatedAt desc, id asc (stable tie-breaker)
 * updatedAt is written explicitly in mutation paths — no DB triggers.
 * Status transitions write a StatusHistory row atomically in the same transaction.
 */

import { db } from '../db/client.js';
import { withTransaction } from '../db/transaction.js';
import { validateKey, validateNonEmpty } from '../enforcement/mutation.js';
import { PROJECT_STATUSES, type ProjectStatus } from '../enforcement/vocabulary.js';
import { checkTransition } from '../enforcement/transitions.js';
import { encodeCursor, decodeCursor } from '../lib/cursor.js';
import { resolveActor } from '../lib/actor.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ProjectRow {
  id: string;
  key: string;
  name: string;
  status: string;
  description: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface ListProjectsInput {
  status?: string;
  limit?: number;
  cursor?: string;
}

export interface ListProjectsResult {
  data: ProjectRow[];
  nextCursor: string | null;
}

export interface CreateProjectInput {
  key: string;
  name: string;
  description?: string | null;
}

export interface UpdateProjectInput {
  name?: string;
  description?: string | null;
}

export interface TransitionProjectStatusInput {
  newStatus: string;
  reason?: string | null;
}

export interface TransitionProjectStatusResult {
  project: ProjectRow;
  statusHistoryId: string;
}

// ---------------------------------------------------------------------------
// Validation errors
// ---------------------------------------------------------------------------

export class ProjectValidationError extends Error {
  constructor(
    public readonly statusCode: 400 | 422,
    public readonly code: string,
    message: string
  ) {
    super(message);
    this.name = 'ProjectValidationError';
  }
}

export class ProjectNotFoundError extends Error {
  constructor(projectId: string) {
    super(`Project not found: ${projectId}`);
    this.name = 'ProjectNotFoundError';
  }
}

export class ProjectKeyConflictError extends Error {
  constructor(key: string) {
    super(`Project key already exists: ${key}`);
    this.name = 'ProjectKeyConflictError';
  }
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const MAX_LIMIT = 100;
const DEFAULT_LIMIT = 20;

// ---------------------------------------------------------------------------
// List projects
// ---------------------------------------------------------------------------

export async function listProjects(input: ListProjectsInput): Promise<ListProjectsResult> {
  const limit = Math.min(input.limit ?? DEFAULT_LIMIT, MAX_LIMIT);
  if (limit < 1) {
    throw new ProjectValidationError(400, 'INVALID_LIMIT', 'limit must be a positive integer');
  }

  // Validate status filter if supplied
  if (input.status !== undefined && !(PROJECT_STATUSES as readonly string[]).includes(input.status)) {
    throw new ProjectValidationError(422, 'INVALID_STATUS', `status must be one of: ${PROJECT_STATUSES.join(', ')}`);
  }

  // Decode cursor
  let cursorUpdatedAt: Date | null = null;
  let cursorId: string | null = null;

  if (input.cursor) {
    const decoded = decodeCursor(input.cursor);
    if (!decoded) {
      throw new ProjectValidationError(400, 'INVALID_CURSOR', 'cursor is malformed');
    }
    cursorUpdatedAt = decoded.updatedAt;
    cursorId = decoded.id;
  }

  // Fetch limit+1 to detect next page
  const fetchLimit = limit + 1;

  let rows: ProjectRow[];

  if (cursorUpdatedAt && cursorId) {
    if (input.status !== undefined) {
      rows = await db<ProjectRow[]>`
        SELECT id, key, name, status, description, "createdAt", "updatedAt"
        FROM app.project
        WHERE status = ${input.status}
          AND ("updatedAt", id) < (${cursorUpdatedAt}, ${cursorId}::uuid)
        ORDER BY "updatedAt" DESC, id ASC
        LIMIT ${fetchLimit}
      `;
    } else {
      rows = await db<ProjectRow[]>`
        SELECT id, key, name, status, description, "createdAt", "updatedAt"
        FROM app.project
        WHERE ("updatedAt", id) < (${cursorUpdatedAt}, ${cursorId}::uuid)
        ORDER BY "updatedAt" DESC, id ASC
        LIMIT ${fetchLimit}
      `;
    }
  } else {
    if (input.status !== undefined) {
      rows = await db<ProjectRow[]>`
        SELECT id, key, name, status, description, "createdAt", "updatedAt"
        FROM app.project
        WHERE status = ${input.status}
        ORDER BY "updatedAt" DESC, id ASC
        LIMIT ${fetchLimit}
      `;
    } else {
      rows = await db<ProjectRow[]>`
        SELECT id, key, name, status, description, "createdAt", "updatedAt"
        FROM app.project
        ORDER BY "updatedAt" DESC, id ASC
        LIMIT ${fetchLimit}
      `;
    }
  }

  const hasMore = rows.length > limit;
  const page = hasMore ? rows.slice(0, limit) : rows;
  const lastRow = page[page.length - 1];
  const nextCursor = hasMore && lastRow
    ? encodeCursor({ updatedAt: lastRow.updatedAt, id: lastRow.id })
    : null;

  return { data: page, nextCursor };
}

// ---------------------------------------------------------------------------
// Get project by id
// ---------------------------------------------------------------------------

export async function getProject(projectId: string): Promise<ProjectRow> {
  const rows = await db<ProjectRow[]>`
    SELECT id, key, name, status, description, "createdAt", "updatedAt"
    FROM app.project
    WHERE id = ${projectId}
  `;
  const row = rows[0];
  if (!row) throw new ProjectNotFoundError(projectId);
  return row;
}

// ---------------------------------------------------------------------------
// Create project
// ---------------------------------------------------------------------------

export async function createProject(input: CreateProjectInput): Promise<ProjectRow> {
  // Validate key
  const keyErr = validateKey(input.key);
  if (keyErr) throw new ProjectValidationError(400, 'INVALID_KEY', keyErr);

  // Validate name
  const nameErr = validateNonEmpty('name', input.name);
  if (nameErr) throw new ProjectValidationError(400, 'INVALID_NAME', nameErr);

  try {
    const rows = await db<ProjectRow[]>`
      INSERT INTO app.project (key, name, description)
      VALUES (${input.key}, ${input.name.trim()}, ${input.description ?? null})
      RETURNING id, key, name, status, description, "createdAt", "updatedAt"
    `;
    return rows[0]!;
  } catch (err: unknown) {
    if (isUniqueViolation(err)) {
      throw new ProjectKeyConflictError(input.key);
    }
    throw err;
  }
}

// ---------------------------------------------------------------------------
// Update project (bounded non-status fields)
// ---------------------------------------------------------------------------

export async function updateProject(
  projectId: string,
  input: UpdateProjectInput
): Promise<ProjectRow> {
  // Must update at least one field
  if (input.name === undefined && input.description === undefined) {
    throw new ProjectValidationError(400, 'NO_MUTABLE_FIELDS', 'request body must include at least one mutable field');
  }

  // Validate name if provided
  if (input.name !== undefined) {
    const nameErr = validateNonEmpty('name', input.name);
    if (nameErr) throw new ProjectValidationError(400, 'INVALID_NAME', nameErr);
  }

  const now = new Date();

  // Build update: only name or description may be mutated
  if (input.name !== undefined && input.description !== undefined) {
    const rows = await db<ProjectRow[]>`
      UPDATE app.project
      SET name = ${input.name.trim()}, description = ${input.description}, "updatedAt" = ${now}
      WHERE id = ${projectId}
      RETURNING id, key, name, status, description, "createdAt", "updatedAt"
    `;
    const row = rows[0];
    if (!row) throw new ProjectNotFoundError(projectId);
    return row;
  }

  if (input.name !== undefined) {
    const rows = await db<ProjectRow[]>`
      UPDATE app.project
      SET name = ${input.name.trim()}, "updatedAt" = ${now}
      WHERE id = ${projectId}
      RETURNING id, key, name, status, description, "createdAt", "updatedAt"
    `;
    const row = rows[0];
    if (!row) throw new ProjectNotFoundError(projectId);
    return row;
  }

  // description only
  const rows = await db<ProjectRow[]>`
    UPDATE app.project
    SET description = ${input.description!}, "updatedAt" = ${now}
    WHERE id = ${projectId}
    RETURNING id, key, name, status, description, "createdAt", "updatedAt"
  `;
  const row = rows[0];
  if (!row) throw new ProjectNotFoundError(projectId);
  return row;
}

// ---------------------------------------------------------------------------
// Transition project status
// ---------------------------------------------------------------------------

export async function transitionProjectStatus(
  projectId: string,
  input: TransitionProjectStatusInput
): Promise<TransitionProjectStatusResult> {
  // Validate newStatus vocabulary
  if (!(PROJECT_STATUSES as readonly string[]).includes(input.newStatus)) {
    throw new ProjectValidationError(422, 'INVALID_STATUS', `newStatus must be one of: ${PROJECT_STATUSES.join(', ')}`);
  }

  return withTransaction(async (tx) => {
    // Load current project (lock for update)
    const rows = await tx<ProjectRow[]>`
      SELECT id, key, name, status, description, "createdAt", "updatedAt"
      FROM app.project
      WHERE id = ${projectId}
      FOR UPDATE
    `;
    const project = rows[0];
    if (!project) throw new ProjectNotFoundError(projectId);

    // Check transition
    const check = checkTransition('project', project.status, input.newStatus);
    if (!check || check.verdict === 'forbidden') {
      throw new ProjectValidationError(
        422,
        'FORBIDDEN_TRANSITION',
        `Transition from '${project.status}' to '${input.newStatus}' is not allowed`
      );
    }

    // Reason required?
    if (check.requiresReason) {
      if (!input.reason || input.reason.trim().length === 0) {
        throw new ProjectValidationError(
          400,
          'REASON_REQUIRED',
          `A reason is required for the '${project.status}' -> '${input.newStatus}' transition`
        );
      }
    }

    const now = new Date();

    // Update project status + updatedAt
    await tx`
      UPDATE app.project
      SET status = ${input.newStatus}, "updatedAt" = ${now}
      WHERE id = ${projectId}
    `;

    // Write StatusHistory row atomically
    const historyRows = await tx<{ id: string }[]>`
      INSERT INTO app.status_history
        ("projectId", "entityType", "entityId", "previousStatus", "newStatus", reason, actor)
      VALUES
        (${projectId}, 'project', ${projectId}, ${project.status}, ${input.newStatus}, ${input.reason ?? null}, ${resolveActor()})
      RETURNING id
    `;
    const statusHistoryId = historyRows[0]!.id;

    // Fetch updated project
    const updatedRows = await tx<ProjectRow[]>`
      SELECT id, key, name, status, description, "createdAt", "updatedAt"
      FROM app.project
      WHERE id = ${projectId}
    `;

    return { project: updatedRows[0]!, statusHistoryId };
  });
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

function isUniqueViolation(err: unknown): boolean {
  return (
    typeof err === 'object' &&
    err !== null &&
    'code' in err &&
    (err as { code: string }).code === '23505'
  );
}
