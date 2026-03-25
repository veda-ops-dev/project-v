/**
 * services/objective.ts
 *
 * Objective service — owns all Objective query, validation, and mutation logic.
 *
 * Authority: docs/api/objectives-api.md
 *            docs/architecture/data/schema-specification.md §2 Objective
 *            docs/architecture/data/status-transitions.md (Objective transitions)
 *            docs/api/api-conventions.md (Pagination, Transaction, Error Code rules)
 *
 * Ordering rule: priority asc, updatedAt desc, id asc (per objectives-api.md)
 *
 * Cursor pagination note:
 *   The governed ordering (priority ASC, updatedAt DESC, id ASC) uses mixed sort
 *   directions. PostgreSQL tuple comparison (a, b, c) > (x, y, z) applies the same
 *   direction to all columns and cannot express mixed ASC/DESC semantics correctly.
 *   Therefore cursor continuation uses decomposed WHERE conditions instead of
 *   tuple comparison. See listObjectives for the explicit implementation.
 *
 * updatedAt is written explicitly in mutation paths — no DB triggers.
 * Status transitions write a StatusHistory row atomically in the same transaction.
 */

import { db } from '../db/client.js';
import { withTransaction } from '../db/transaction.js';
import { validateKey, validateNonEmpty, validatePriority } from '../enforcement/mutation.js';
import { OBJECTIVE_STATUSES, isAllowed, PRIORITY_DEFAULT } from '../enforcement/vocabulary.js';
import { checkTransition } from '../enforcement/transitions.js';
import { loadProject, isProjectOpenForChildren } from '../enforcement/scope.js';
import { resolveActor } from '../lib/actor.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ObjectiveRow {
  id: string;
  projectId: string;
  key: string;
  title: string;
  description: string | null;
  status: string;
  priority: number;
  targetStartAt: Date | null;
  targetEndAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface ListObjectivesInput {
  projectId: string;
  status?: string;
  priority?: number;
  limit?: number;
  cursor?: string;
}

export interface ListObjectivesResult {
  data: ObjectiveRow[];
  nextCursor: string | null;
}

export interface CreateObjectiveInput {
  projectId: string;
  key: string;
  title: string;
  description?: string | null;
  priority?: number;
  targetStartAt?: string | null;
  targetEndAt?: string | null;
}

export interface UpdateObjectiveInput {
  title?: string;
  description?: string | null;
  priority?: number;
  targetStartAt?: string | Date | null;
  targetEndAt?: string | Date | null;
}

export interface TransitionObjectiveStatusInput {
  newStatus: string;
  reason?: string | null;
}

export interface TransitionObjectiveStatusResult {
  objective: ObjectiveRow;
  statusHistoryId: string;
}

// ---------------------------------------------------------------------------
// Validation errors
// ---------------------------------------------------------------------------

export class ObjectiveValidationError extends Error {
  constructor(
    public readonly statusCode: 400 | 422,
    public readonly code: string,
    message: string
  ) {
    super(message);
    this.name = 'ObjectiveValidationError';
  }
}

export class ObjectiveNotFoundError extends Error {
  constructor(objectiveId: string, projectId: string) {
    super(`Objective not found: ${objectiveId} in project ${projectId}`);
    this.name = 'ObjectiveNotFoundError';
  }
}

export class ObjectiveKeyConflictError extends Error {
  constructor(key: string) {
    super(`Objective key already exists in this project: ${key}`);
    this.name = 'ObjectiveKeyConflictError';
  }
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const MAX_LIMIT = 100;
const DEFAULT_LIMIT = 20;

const SELECT_COLS = `id, "projectId", key, title, description, status, priority, "targetStartAt", "targetEndAt", "createdAt", "updatedAt"`;

// ---------------------------------------------------------------------------
// Cursor helpers for objective ordering
// ---------------------------------------------------------------------------
// Objective ordering: priority ASC, "updatedAt" DESC, id ASC
//
// Mixed-direction ordering means PostgreSQL tuple comparison cannot be used
// directly. Instead, cursor pagination decomposes the WHERE clause into
// explicit conditions that correctly skip past the last seen row.
//
// For ordering (A asc, B desc, C asc), "next page after row (a, b, c)" means:
//   WHERE A > a
//      OR (A = a AND B < b)
//      OR (A = a AND B = b AND C > c)

interface ObjectiveCursorPayload {
  p: number;   // priority
  u: string;   // updatedAt ISO
  i: string;   // id
}

function encodeObjectiveCursor(row: ObjectiveRow): string {
  const raw = JSON.stringify({
    p: row.priority,
    u: row.updatedAt.toISOString(),
    i: row.id,
  });
  return Buffer.from(raw).toString('base64url');
}

function decodeObjectiveCursor(cursor: string): ObjectiveCursorPayload | null {
  try {
    const raw = Buffer.from(cursor, 'base64url').toString('utf8');
    const parsed = JSON.parse(raw) as { p?: unknown; u?: unknown; i?: unknown };
    if (typeof parsed.p !== 'number' || !Number.isInteger(parsed.p)) return null;
    if (typeof parsed.u !== 'string' || typeof parsed.i !== 'string') return null;
    const d = new Date(parsed.u);
    if (isNaN(d.getTime())) return null;
    return { p: parsed.p, u: parsed.u, i: parsed.i };
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------
// List objectives
// ---------------------------------------------------------------------------

export async function listObjectives(input: ListObjectivesInput): Promise<ListObjectivesResult> {
  const limit = Math.min(input.limit ?? DEFAULT_LIMIT, MAX_LIMIT);
  if (limit < 1) {
    throw new ObjectiveValidationError(400, 'INVALID_LIMIT', 'limit must be a positive integer');
  }

  // Validate status filter
  if (input.status !== undefined && !isAllowed(input.status, OBJECTIVE_STATUSES)) {
    throw new ObjectiveValidationError(422, 'INVALID_STATUS', `status must be one of: ${OBJECTIVE_STATUSES.join(', ')}`);
  }

  // Validate priority filter
  if (input.priority !== undefined) {
    const priErr = validatePriority(input.priority);
    if (priErr) throw new ObjectiveValidationError(422, 'INVALID_PRIORITY', priErr);
  }

  // Verify project exists (returns 404 for missing project)
  const project = await loadProject(input.projectId);
  if (!project) {
    throw new ObjectiveNotFoundError('(list)', input.projectId);
  }

  // Decode cursor
  let cur: ObjectiveCursorPayload | null = null;
  if (input.cursor) {
    cur = decodeObjectiveCursor(input.cursor);
    if (!cur) {
      throw new ObjectiveValidationError(400, 'INVALID_CURSOR', 'cursor is malformed');
    }
  }

  const fetchLimit = limit + 1;

  // Build query with decomposed cursor WHERE clause for mixed-direction ordering.
  // Ordering: priority ASC, "updatedAt" DESC, id ASC
  // Cursor continuation (after row with priority=P, updatedAt=U, id=I):
  //   priority > P
  //   OR (priority = P AND "updatedAt" < U)
  //   OR (priority = P AND "updatedAt" = U AND id > I)
  let rows: ObjectiveRow[];

  if (cur) {
    const curUpdatedAt = new Date(cur.u);

    if (input.status !== undefined && input.priority !== undefined) {
      rows = await db<ObjectiveRow[]>`
        SELECT ${db.unsafe(SELECT_COLS)}
        FROM app.objective
        WHERE "projectId" = ${input.projectId}
          AND status = ${input.status}
          AND priority = ${input.priority}
          AND (
            priority > ${cur.p}
            OR (priority = ${cur.p} AND "updatedAt" < ${curUpdatedAt})
            OR (priority = ${cur.p} AND "updatedAt" = ${curUpdatedAt} AND id > ${cur.i}::uuid)
          )
        ORDER BY priority ASC, "updatedAt" DESC, id ASC
        LIMIT ${fetchLimit}
      `;
    } else if (input.status !== undefined) {
      rows = await db<ObjectiveRow[]>`
        SELECT ${db.unsafe(SELECT_COLS)}
        FROM app.objective
        WHERE "projectId" = ${input.projectId}
          AND status = ${input.status}
          AND (
            priority > ${cur.p}
            OR (priority = ${cur.p} AND "updatedAt" < ${curUpdatedAt})
            OR (priority = ${cur.p} AND "updatedAt" = ${curUpdatedAt} AND id > ${cur.i}::uuid)
          )
        ORDER BY priority ASC, "updatedAt" DESC, id ASC
        LIMIT ${fetchLimit}
      `;
    } else if (input.priority !== undefined) {
      rows = await db<ObjectiveRow[]>`
        SELECT ${db.unsafe(SELECT_COLS)}
        FROM app.objective
        WHERE "projectId" = ${input.projectId}
          AND priority = ${input.priority}
          AND (
            priority > ${cur.p}
            OR (priority = ${cur.p} AND "updatedAt" < ${curUpdatedAt})
            OR (priority = ${cur.p} AND "updatedAt" = ${curUpdatedAt} AND id > ${cur.i}::uuid)
          )
        ORDER BY priority ASC, "updatedAt" DESC, id ASC
        LIMIT ${fetchLimit}
      `;
    } else {
      rows = await db<ObjectiveRow[]>`
        SELECT ${db.unsafe(SELECT_COLS)}
        FROM app.objective
        WHERE "projectId" = ${input.projectId}
          AND (
            priority > ${cur.p}
            OR (priority = ${cur.p} AND "updatedAt" < ${curUpdatedAt})
            OR (priority = ${cur.p} AND "updatedAt" = ${curUpdatedAt} AND id > ${cur.i}::uuid)
          )
        ORDER BY priority ASC, "updatedAt" DESC, id ASC
        LIMIT ${fetchLimit}
      `;
    }
  } else {
    // No cursor — first page
    if (input.status !== undefined && input.priority !== undefined) {
      rows = await db<ObjectiveRow[]>`
        SELECT ${db.unsafe(SELECT_COLS)}
        FROM app.objective
        WHERE "projectId" = ${input.projectId}
          AND status = ${input.status}
          AND priority = ${input.priority}
        ORDER BY priority ASC, "updatedAt" DESC, id ASC
        LIMIT ${fetchLimit}
      `;
    } else if (input.status !== undefined) {
      rows = await db<ObjectiveRow[]>`
        SELECT ${db.unsafe(SELECT_COLS)}
        FROM app.objective
        WHERE "projectId" = ${input.projectId}
          AND status = ${input.status}
        ORDER BY priority ASC, "updatedAt" DESC, id ASC
        LIMIT ${fetchLimit}
      `;
    } else if (input.priority !== undefined) {
      rows = await db<ObjectiveRow[]>`
        SELECT ${db.unsafe(SELECT_COLS)}
        FROM app.objective
        WHERE "projectId" = ${input.projectId}
          AND priority = ${input.priority}
        ORDER BY priority ASC, "updatedAt" DESC, id ASC
        LIMIT ${fetchLimit}
      `;
    } else {
      rows = await db<ObjectiveRow[]>`
        SELECT ${db.unsafe(SELECT_COLS)}
        FROM app.objective
        WHERE "projectId" = ${input.projectId}
        ORDER BY priority ASC, "updatedAt" DESC, id ASC
        LIMIT ${fetchLimit}
      `;
    }
  }

  const hasMore = rows.length > limit;
  const page = hasMore ? rows.slice(0, limit) : rows;
  const lastRow = page[page.length - 1];
  const nextCursor = hasMore && lastRow
    ? encodeObjectiveCursor(lastRow)
    : null;

  return { data: page, nextCursor };
}

// ---------------------------------------------------------------------------
// Get objective by id (project-scoped)
// ---------------------------------------------------------------------------

export async function getObjective(projectId: string, objectiveId: string): Promise<ObjectiveRow> {
  const rows = await db<ObjectiveRow[]>`
    SELECT ${db.unsafe(SELECT_COLS)}
    FROM app.objective
    WHERE id = ${objectiveId} AND "projectId" = ${projectId}
  `;
  const row = rows[0];
  if (!row) throw new ObjectiveNotFoundError(objectiveId, projectId);
  return row;
}

// ---------------------------------------------------------------------------
// Create objective
// ---------------------------------------------------------------------------

export async function createObjective(input: CreateObjectiveInput): Promise<ObjectiveRow> {
  // Validate key
  const keyErr = validateKey(input.key);
  if (keyErr) throw new ObjectiveValidationError(400, 'INVALID_KEY', keyErr);

  // Validate title
  const titleErr = validateNonEmpty('title', input.title);
  if (titleErr) throw new ObjectiveValidationError(400, 'INVALID_TITLE', titleErr);

  // Validate priority if supplied
  const priority = input.priority ?? PRIORITY_DEFAULT;
  const priErr = validatePriority(priority);
  if (priErr) throw new ObjectiveValidationError(422, 'INVALID_PRIORITY', priErr);

  // Validate date ordering if both supplied
  const startAt = input.targetStartAt ? new Date(input.targetStartAt) : null;
  const endAt = input.targetEndAt ? new Date(input.targetEndAt) : null;

  if (startAt && isNaN(startAt.getTime())) {
    throw new ObjectiveValidationError(400, 'INVALID_DATE', 'targetStartAt must be a valid date');
  }
  if (endAt && isNaN(endAt.getTime())) {
    throw new ObjectiveValidationError(400, 'INVALID_DATE', 'targetEndAt must be a valid date');
  }
  if (startAt && endAt && endAt < startAt) {
    throw new ObjectiveValidationError(422, 'INVALID_DATE_ORDER', 'targetEndAt must not precede targetStartAt');
  }

  // Verify project exists and is not archived
  const open = await isProjectOpenForChildren(input.projectId);
  if (!open) {
    // Check whether project exists at all vs archived
    const project = await loadProject(input.projectId);
    if (!project) {
      throw new ObjectiveNotFoundError('(create)', input.projectId);
    }
    throw new ObjectiveValidationError(422, 'PROJECT_ARCHIVED', 'Cannot create objectives under an archived project');
  }

  try {
    const rows = await db<ObjectiveRow[]>`
      INSERT INTO app.objective ("projectId", key, title, description, priority, "targetStartAt", "targetEndAt")
      VALUES (
        ${input.projectId},
        ${input.key},
        ${input.title.trim()},
        ${input.description ?? null},
        ${priority},
        ${startAt},
        ${endAt}
      )
      RETURNING ${db.unsafe(SELECT_COLS)}
    `;
    return rows[0]!;
  } catch (err: unknown) {
    if (isUniqueViolation(err)) {
      throw new ObjectiveKeyConflictError(input.key);
    }
    if (isForeignKeyViolation(err)) {
      throw new ObjectiveNotFoundError('(create)', input.projectId);
    }
    throw err;
  }
}

// ---------------------------------------------------------------------------
// Update objective (bounded non-status fields)
// ---------------------------------------------------------------------------

export async function updateObjective(
  projectId: string,
  objectiveId: string,
  input: UpdateObjectiveInput
): Promise<ObjectiveRow> {
  // Must update at least one field
  if (
    input.title === undefined &&
    input.description === undefined &&
    input.priority === undefined &&
    input.targetStartAt === undefined &&
    input.targetEndAt === undefined
  ) {
    throw new ObjectiveValidationError(400, 'NO_MUTABLE_FIELDS', 'request body must include at least one mutable field');
  }

  // Validate title if provided
  if (input.title !== undefined) {
    const titleErr = validateNonEmpty('title', input.title);
    if (titleErr) throw new ObjectiveValidationError(400, 'INVALID_TITLE', titleErr);
  }

  // Validate priority if provided
  if (input.priority !== undefined) {
    const priErr = validatePriority(input.priority);
    if (priErr) throw new ObjectiveValidationError(422, 'INVALID_PRIORITY', priErr);
  }

  // Parse dates if provided
  let parsedStartAt: Date | null | undefined = undefined;
  let parsedEndAt: Date | null | undefined = undefined;

  if (input.targetStartAt !== undefined) {
    if (input.targetStartAt === null) {
      parsedStartAt = null;
    } else {
      parsedStartAt = new Date(input.targetStartAt as string);
      if (isNaN(parsedStartAt.getTime())) {
        throw new ObjectiveValidationError(400, 'INVALID_DATE', 'targetStartAt must be a valid date');
      }
    }
  }
  if (input.targetEndAt !== undefined) {
    if (input.targetEndAt === null) {
      parsedEndAt = null;
    } else {
      parsedEndAt = new Date(input.targetEndAt as string);
      if (isNaN(parsedEndAt.getTime())) {
        throw new ObjectiveValidationError(400, 'INVALID_DATE', 'targetEndAt must be a valid date');
      }
    }
  }

  const now = new Date();

  // Load current objective to merge date fields for ordering check
  const current = await getObjective(projectId, objectiveId);

  // Determine effective dates for ordering check
  const effectiveStart = parsedStartAt !== undefined ? parsedStartAt : current.targetStartAt;
  const effectiveEnd = parsedEndAt !== undefined ? parsedEndAt : current.targetEndAt;

  if (effectiveStart && effectiveEnd && effectiveEnd < effectiveStart) {
    throw new ObjectiveValidationError(422, 'INVALID_DATE_ORDER', 'targetEndAt must not precede targetStartAt');
  }

  // Full UPDATE with coalesced values. This is explicit and safe — no dynamic
  // SQL string building. Each field is either the new value or the existing value.
  const newTitle = input.title !== undefined ? input.title.trim() : current.title;
  const newDescription = input.description !== undefined ? input.description : current.description;
  const newPriority = input.priority !== undefined ? input.priority : current.priority;
  const newStartAt = parsedStartAt !== undefined ? parsedStartAt : current.targetStartAt;
  const newEndAt = parsedEndAt !== undefined ? parsedEndAt : current.targetEndAt;

  const rows = await db<ObjectiveRow[]>`
    UPDATE app.objective
    SET
      title = ${newTitle},
      description = ${newDescription},
      priority = ${newPriority},
      "targetStartAt" = ${newStartAt},
      "targetEndAt" = ${newEndAt},
      "updatedAt" = ${now}
    WHERE id = ${objectiveId} AND "projectId" = ${projectId}
    RETURNING ${db.unsafe(SELECT_COLS)}
  `;

  const row = rows[0];
  if (!row) throw new ObjectiveNotFoundError(objectiveId, projectId);
  return row;
}

// ---------------------------------------------------------------------------
// Transition objective status
// ---------------------------------------------------------------------------

export async function transitionObjectiveStatus(
  projectId: string,
  objectiveId: string,
  input: TransitionObjectiveStatusInput
): Promise<TransitionObjectiveStatusResult> {
  // Validate newStatus vocabulary
  if (!isAllowed(input.newStatus, OBJECTIVE_STATUSES)) {
    throw new ObjectiveValidationError(
      422,
      'INVALID_STATUS',
      `newStatus must be one of: ${OBJECTIVE_STATUSES.join(', ')}`
    );
  }

  return withTransaction(async (tx) => {
    // Load current objective (lock for update, project-scoped)
    const rows = await tx<ObjectiveRow[]>`
      SELECT ${tx.unsafe(SELECT_COLS)}
      FROM app.objective
      WHERE id = ${objectiveId} AND "projectId" = ${projectId}
      FOR UPDATE
    `;
    const objective = rows[0];
    if (!objective) throw new ObjectiveNotFoundError(objectiveId, projectId);

    // Check transition legality
    const check = checkTransition('objective', objective.status, input.newStatus);
    if (!check || check.verdict === 'forbidden') {
      throw new ObjectiveValidationError(
        422,
        'FORBIDDEN_TRANSITION',
        `Transition from '${objective.status}' to '${input.newStatus}' is not allowed`
      );
    }

    // Reason required?
    if (check.requiresReason) {
      if (!input.reason || input.reason.trim().length === 0) {
        throw new ObjectiveValidationError(
          400,
          'REASON_REQUIRED',
          `A reason is required for the '${objective.status}' -> '${input.newStatus}' transition`
        );
      }
    }

    const now = new Date();

    // Update objective status + updatedAt
    await tx`
      UPDATE app.objective
      SET status = ${input.newStatus}, "updatedAt" = ${now}
      WHERE id = ${objectiveId} AND "projectId" = ${projectId}
    `;

    // Write StatusHistory row atomically
    const historyRows = await tx<{ id: string }[]>`
      INSERT INTO app.status_history
        ("projectId", "entityType", "entityId", "previousStatus", "newStatus", reason, actor)
      VALUES
        (${projectId}, 'objective', ${objectiveId}, ${objective.status}, ${input.newStatus}, ${input.reason ?? null}, ${resolveActor()})
      RETURNING id
    `;
    const statusHistoryId = historyRows[0]!.id;

    // Fetch updated objective
    const updatedRows = await tx<ObjectiveRow[]>`
      SELECT ${tx.unsafe(SELECT_COLS)}
      FROM app.objective
      WHERE id = ${objectiveId} AND "projectId" = ${projectId}
    `;

    return { objective: updatedRows[0]!, statusHistoryId };
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

function isForeignKeyViolation(err: unknown): boolean {
  return (
    typeof err === 'object' &&
    err !== null &&
    'code' in err &&
    (err as { code: string }).code === '23503'
  );
}
