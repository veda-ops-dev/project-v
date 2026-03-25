/**
 * services/initiative.ts
 *
 * Initiative service — owns all Initiative query, validation, and mutation logic.
 *
 * Authority: docs/api/initiatives-api.md
 *            docs/architecture/data/schema-specification.md §3 Initiative
 *            docs/architecture/data/status-transitions.md (Initiative transitions)
 *            docs/api/api-conventions.md (Pagination, Transaction, Error Code rules)
 *
 * Ordering rule: priority asc, updatedAt desc, id asc (per initiatives-api.md)
 *
 * Cursor pagination note:
 *   The governed ordering (priority ASC, updatedAt DESC, id ASC) uses mixed sort
 *   directions. PostgreSQL tuple comparison (a, b, c) > (x, y, z) applies the same
 *   direction to all columns and cannot express mixed ASC/DESC semantics correctly.
 *   Therefore cursor continuation uses decomposed WHERE conditions instead of
 *   tuple comparison. See listInitiatives for the explicit implementation.
 *
 * List query construction note:
 *   Initiative has 4 optional filters (status, priority, objectiveId, targetSystem)
 *   plus cursor — too many combinations for exhaustive branching. The list query
 *   uses composable SQL fragments via the postgres library's tagged template helper
 *   so that all filter values remain parameterized. No user-supplied values appear
 *   in db.unsafe() calls.
 *
 * updatedAt is written explicitly in mutation paths — no DB triggers.
 * Status transitions write a StatusHistory row atomically in the same transaction.
 */

import { db } from '../db/client.js';
import { withTransaction } from '../db/transaction.js';
import { validateKey, validateNonEmpty, validatePriority } from '../enforcement/mutation.js';
import { INITIATIVE_STATUSES, INITIATIVE_TARGET_SYSTEMS, isAllowed, PRIORITY_DEFAULT } from '../enforcement/vocabulary.js';
import { checkTransition } from '../enforcement/transitions.js';
import { loadProject, isProjectOpenForChildren } from '../enforcement/scope.js';
import { resolveActor } from '../lib/actor.js';
import { ProjectNotFoundError } from './project.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface InitiativeRow {
  id: string;
  projectId: string;
  objectiveId: string | null;
  key: string;
  title: string;
  description: string | null;
  status: string;
  priority: number;
  targetSystem: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface ListInitiativesInput {
  projectId: string;
  status?: string;
  priority?: number;
  objectiveId?: string;
  targetSystem?: string;
  limit?: number;
  cursor?: string;
}

export interface ListInitiativesResult {
  data: InitiativeRow[];
  nextCursor: string | null;
}

export interface CreateInitiativeInput {
  projectId: string;
  key: string;
  title: string;
  description?: string | null;
  objectiveId?: string | null;
  priority?: number;
  targetSystem?: string | null;
}

export interface UpdateInitiativeInput {
  title?: string;
  description?: string | null;
  objectiveId?: string | null;
  priority?: number;
  targetSystem?: string | null;
}

export interface TransitionInitiativeStatusInput {
  newStatus: string;
  reason?: string | null;
}

export interface TransitionInitiativeStatusResult {
  initiative: InitiativeRow;
  statusHistoryId: string;
}

// ---------------------------------------------------------------------------
// Validation errors
// ---------------------------------------------------------------------------

export class InitiativeValidationError extends Error {
  constructor(
    public readonly statusCode: 400 | 422,
    public readonly code: string,
    message: string
  ) {
    super(message);
    this.name = 'InitiativeValidationError';
  }
}

export class InitiativeNotFoundError extends Error {
  constructor(initiativeId: string, projectId: string) {
    super(`Initiative not found: ${initiativeId} in project ${projectId}`);
    this.name = 'InitiativeNotFoundError';
  }
}

export class InitiativeKeyConflictError extends Error {
  constructor(key: string) {
    super(`Initiative key already exists in this project: ${key}`);
    this.name = 'InitiativeKeyConflictError';
  }
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const MAX_LIMIT = 100;
const DEFAULT_LIMIT = 20;

const SELECT_COLS = `id, "projectId", "objectiveId", key, title, description, status, priority, "targetSystem", "createdAt", "updatedAt"`;

// ---------------------------------------------------------------------------
// Cursor helpers for initiative ordering
// ---------------------------------------------------------------------------
// Initiative ordering: priority ASC, "updatedAt" DESC, id ASC
//
// Mixed-direction ordering means PostgreSQL tuple comparison cannot be used
// directly. Instead, cursor pagination decomposes the WHERE clause into
// explicit conditions that correctly skip past the last seen row.
//
// For ordering (A asc, B desc, C asc), "next page after row (a, b, c)" means:
//   WHERE A > a
//      OR (A = a AND B < b)
//      OR (A = a AND B = b AND C > c)

interface InitiativeCursorPayload {
  p: number;   // priority
  u: string;   // updatedAt ISO
  i: string;   // id
}

function encodeInitiativeCursor(row: InitiativeRow): string {
  const raw = JSON.stringify({
    p: row.priority,
    u: row.updatedAt.toISOString(),
    i: row.id,
  });
  return Buffer.from(raw).toString('base64url');
}

function decodeInitiativeCursor(cursor: string): InitiativeCursorPayload | null {
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
// Objective parent validation (same-project, not archived)
// ---------------------------------------------------------------------------

/**
 * Verify that the referenced objectiveId exists in the given project and is not archived.
 *
 * Returns the objective status on success.
 * Returns null if the objective does not exist OR belongs to another project
 * (same "unavailable" shape for both — prevents cross-project existence leakage).
 *
 * Authority: docs/api/initiatives-api.md (Validation)
 *            docs/architecture/core/multi-project-doctrine.md §3
 */
async function loadObjectiveInProject(
  objectiveId: string,
  projectId: string,
  tx?: typeof db
): Promise<{ id: string; status: string } | null> {
  const sql = tx ?? db;
  const rows = await sql<{ id: string; status: string }[]>`
    SELECT id, status
    FROM app.objective
    WHERE id = ${objectiveId} AND "projectId" = ${projectId}
  `;
  return rows[0] ?? null;
}

// ---------------------------------------------------------------------------
// List initiatives
// ---------------------------------------------------------------------------

export async function listInitiatives(input: ListInitiativesInput): Promise<ListInitiativesResult> {
  const limit = Math.min(input.limit ?? DEFAULT_LIMIT, MAX_LIMIT);
  if (limit < 1) {
    throw new InitiativeValidationError(400, 'INVALID_LIMIT', 'limit must be a positive integer');
  }

  // Validate status filter
  if (input.status !== undefined && !isAllowed(input.status, INITIATIVE_STATUSES)) {
    throw new InitiativeValidationError(422, 'INVALID_STATUS', `status must be one of: ${INITIATIVE_STATUSES.join(', ')}`);
  }

  // Validate priority filter
  if (input.priority !== undefined) {
    const priErr = validatePriority(input.priority);
    if (priErr) throw new InitiativeValidationError(422, 'INVALID_PRIORITY', priErr);
  }

  // Validate targetSystem filter
  if (input.targetSystem !== undefined && !isAllowed(input.targetSystem, INITIATIVE_TARGET_SYSTEMS)) {
    throw new InitiativeValidationError(422, 'INVALID_TARGET_SYSTEM', `targetSystem must be one of: ${INITIATIVE_TARGET_SYSTEMS.join(', ')}`);
  }

  // Validate objectiveId filter format
  if (input.objectiveId !== undefined && !UUID_REGEX.test(input.objectiveId)) {
    throw new InitiativeValidationError(400, 'INVALID_ID', 'objectiveId filter must be a valid UUID');
  }

  // Verify project exists — a missing project is a project-not-found error,
  // not an initiative-not-found error.
  const project = await loadProject(input.projectId);
  if (!project) {
    throw new ProjectNotFoundError(input.projectId);
  }

  // Decode cursor
  let cur: InitiativeCursorPayload | null = null;
  if (input.cursor) {
    cur = decodeInitiativeCursor(input.cursor);
    if (!cur) {
      throw new InitiativeValidationError(400, 'INVALID_CURSOR', 'cursor is malformed');
    }
  }

  const fetchLimit = limit + 1;

  // Build composable WHERE fragments using postgres tagged templates.
  // Each fragment is parameterized — no user-supplied values in db.unsafe().
  // Type annotation omitted; TypeScript infers from the db tagged template return.
  const fragments = [
    db`"projectId" = ${input.projectId}`,
  ];

  if (input.status !== undefined) {
    fragments.push(db`status = ${input.status}`);
  }
  if (input.priority !== undefined) {
    fragments.push(db`priority = ${input.priority}`);
  }
  if (input.objectiveId !== undefined) {
    fragments.push(db`"objectiveId" = ${input.objectiveId}::uuid`);
  }
  if (input.targetSystem !== undefined) {
    fragments.push(db`"targetSystem" = ${input.targetSystem}`);
  }

  if (cur) {
    const curUpdatedAt = new Date(cur.u);
    fragments.push(db`(
      priority > ${cur.p}
      OR (priority = ${cur.p} AND "updatedAt" < ${curUpdatedAt})
      OR (priority = ${cur.p} AND "updatedAt" = ${curUpdatedAt} AND id > ${cur.i}::uuid)
    )`);
  }

  // Combine fragments with AND. The postgres library supports embedding
  // tagged template results as expression interpolation in other templates.
  let where = fragments[0]!;
  for (let i = 1; i < fragments.length; i++) {
    where = db`${where} AND ${fragments[i]!}`;
  }

  const rows = await db<InitiativeRow[]>`
    SELECT ${db.unsafe(SELECT_COLS)}
    FROM app.initiative
    WHERE ${where}
    ORDER BY priority ASC, "updatedAt" DESC, id ASC
    LIMIT ${fetchLimit}
  `;

  const hasMore = rows.length > limit;
  const page = hasMore ? rows.slice(0, limit) : rows;
  const lastRow = page[page.length - 1];
  const nextCursor = hasMore && lastRow
    ? encodeInitiativeCursor(lastRow)
    : null;

  return { data: page, nextCursor };
}

// ---------------------------------------------------------------------------
// Get initiative by id (project-scoped)
// ---------------------------------------------------------------------------

export async function getInitiative(projectId: string, initiativeId: string): Promise<InitiativeRow> {
  const rows = await db<InitiativeRow[]>`
    SELECT ${db.unsafe(SELECT_COLS)}
    FROM app.initiative
    WHERE id = ${initiativeId} AND "projectId" = ${projectId}
  `;
  const row = rows[0];
  if (!row) throw new InitiativeNotFoundError(initiativeId, projectId);
  return row;
}

// ---------------------------------------------------------------------------
// Create initiative
// ---------------------------------------------------------------------------

export async function createInitiative(input: CreateInitiativeInput): Promise<InitiativeRow> {
  // Validate key
  const keyErr = validateKey(input.key);
  if (keyErr) throw new InitiativeValidationError(400, 'INVALID_KEY', keyErr);

  // Validate title
  const titleErr = validateNonEmpty('title', input.title);
  if (titleErr) throw new InitiativeValidationError(400, 'INVALID_TITLE', titleErr);

  // Validate priority if supplied
  const priority = input.priority ?? PRIORITY_DEFAULT;
  const priErr = validatePriority(priority);
  if (priErr) throw new InitiativeValidationError(422, 'INVALID_PRIORITY', priErr);

  // Validate targetSystem if supplied
  if (input.targetSystem !== undefined && input.targetSystem !== null) {
    if (!isAllowed(input.targetSystem, INITIATIVE_TARGET_SYSTEMS)) {
      throw new InitiativeValidationError(
        422, 'INVALID_TARGET_SYSTEM',
        `targetSystem must be one of: ${INITIATIVE_TARGET_SYSTEMS.join(', ')}`
      );
    }
  }

  // Verify project exists and is not archived
  const open = await isProjectOpenForChildren(input.projectId);
  if (!open) {
    const project = await loadProject(input.projectId);
    if (!project) {
      throw new ProjectNotFoundError(input.projectId);
    }
    throw new InitiativeValidationError(422, 'PROJECT_ARCHIVED', 'Cannot create initiatives under an archived project');
  }

  // Validate objectiveId if supplied: must exist in same project and not be archived
  if (input.objectiveId !== undefined && input.objectiveId !== null) {
    if (!UUID_REGEX.test(input.objectiveId)) {
      throw new InitiativeValidationError(400, 'INVALID_ID', 'objectiveId must be a valid UUID');
    }
    const objective = await loadObjectiveInProject(input.objectiveId, input.projectId);
    if (!objective) {
      // Same "not found" message for missing and wrong-project — prevents existence leakage
      throw new InitiativeValidationError(
        422, 'INVALID_OBJECTIVE',
        `Referenced objective not found in this project: ${input.objectiveId}`
      );
    }
    if (objective.status === 'archived') {
      throw new InitiativeValidationError(
        422, 'OBJECTIVE_ARCHIVED',
        'Cannot link initiative to an archived objective'
      );
    }
  }

  try {
    const rows = await db<InitiativeRow[]>`
      INSERT INTO app.initiative ("projectId", "objectiveId", key, title, description, priority, "targetSystem")
      VALUES (
        ${input.projectId},
        ${input.objectiveId ?? null},
        ${input.key},
        ${input.title.trim()},
        ${input.description ?? null},
        ${priority},
        ${input.targetSystem ?? null}
      )
      RETURNING ${db.unsafe(SELECT_COLS)}
    `;
    return rows[0]!;
  } catch (err: unknown) {
    if (isUniqueViolation(err)) {
      throw new InitiativeKeyConflictError(input.key);
    }
    if (isForeignKeyViolation(err)) {
      throw new ProjectNotFoundError(input.projectId);
    }
    throw err;
  }
}

// ---------------------------------------------------------------------------
// Update initiative (bounded non-status fields)
// ---------------------------------------------------------------------------

export async function updateInitiative(
  projectId: string,
  initiativeId: string,
  input: UpdateInitiativeInput
): Promise<InitiativeRow> {
  // Must update at least one field
  if (
    input.title === undefined &&
    input.description === undefined &&
    input.objectiveId === undefined &&
    input.priority === undefined &&
    input.targetSystem === undefined
  ) {
    throw new InitiativeValidationError(400, 'NO_MUTABLE_FIELDS', 'request body must include at least one mutable field');
  }

  // Validate title if provided
  if (input.title !== undefined) {
    const titleErr = validateNonEmpty('title', input.title);
    if (titleErr) throw new InitiativeValidationError(400, 'INVALID_TITLE', titleErr);
  }

  // Validate priority if provided
  if (input.priority !== undefined) {
    const priErr = validatePriority(input.priority);
    if (priErr) throw new InitiativeValidationError(422, 'INVALID_PRIORITY', priErr);
  }

  // Validate targetSystem if provided
  if (input.targetSystem !== undefined && input.targetSystem !== null) {
    if (!isAllowed(input.targetSystem, INITIATIVE_TARGET_SYSTEMS)) {
      throw new InitiativeValidationError(
        422, 'INVALID_TARGET_SYSTEM',
        `targetSystem must be one of: ${INITIATIVE_TARGET_SYSTEMS.join(', ')}`
      );
    }
  }

  // Load current initiative
  const current = await getInitiative(projectId, initiativeId);

  // Validate objectiveId if being changed
  if (input.objectiveId !== undefined) {
    if (input.objectiveId !== null) {
      if (!UUID_REGEX.test(input.objectiveId)) {
        throw new InitiativeValidationError(400, 'INVALID_ID', 'objectiveId must be a valid UUID');
      }
      const objective = await loadObjectiveInProject(input.objectiveId, projectId);
      if (!objective) {
        throw new InitiativeValidationError(
          422, 'INVALID_OBJECTIVE',
          `Referenced objective not found in this project: ${input.objectiveId}`
        );
      }
      if (objective.status === 'archived') {
        throw new InitiativeValidationError(
          422, 'OBJECTIVE_ARCHIVED',
          'Cannot link initiative to an archived objective'
        );
      }
    }
  }

  const now = new Date();

  const newTitle = input.title !== undefined ? input.title.trim() : current.title;
  const newDescription = input.description !== undefined ? input.description : current.description;
  const newObjectiveId = input.objectiveId !== undefined ? input.objectiveId : current.objectiveId;
  const newPriority = input.priority !== undefined ? input.priority : current.priority;
  const newTargetSystem = input.targetSystem !== undefined ? input.targetSystem : current.targetSystem;

  const rows = await db<InitiativeRow[]>`
    UPDATE app.initiative
    SET
      title = ${newTitle},
      description = ${newDescription},
      "objectiveId" = ${newObjectiveId},
      priority = ${newPriority},
      "targetSystem" = ${newTargetSystem},
      "updatedAt" = ${now}
    WHERE id = ${initiativeId} AND "projectId" = ${projectId}
    RETURNING ${db.unsafe(SELECT_COLS)}
  `;

  const row = rows[0];
  if (!row) throw new InitiativeNotFoundError(initiativeId, projectId);
  return row;
}

// ---------------------------------------------------------------------------
// Transition initiative status
// ---------------------------------------------------------------------------

export async function transitionInitiativeStatus(
  projectId: string,
  initiativeId: string,
  input: TransitionInitiativeStatusInput
): Promise<TransitionInitiativeStatusResult> {
  // Validate newStatus vocabulary
  if (!isAllowed(input.newStatus, INITIATIVE_STATUSES)) {
    throw new InitiativeValidationError(
      422,
      'INVALID_STATUS',
      `newStatus must be one of: ${INITIATIVE_STATUSES.join(', ')}`
    );
  }

  return withTransaction(async (tx) => {
    // Load current initiative (lock for update, project-scoped)
    const rows = await tx<InitiativeRow[]>`
      SELECT ${tx.unsafe(SELECT_COLS)}
      FROM app.initiative
      WHERE id = ${initiativeId} AND "projectId" = ${projectId}
      FOR UPDATE
    `;
    const initiative = rows[0];
    if (!initiative) throw new InitiativeNotFoundError(initiativeId, projectId);

    // Check transition legality
    const check = checkTransition('initiative', initiative.status, input.newStatus);
    if (!check || check.verdict === 'forbidden') {
      throw new InitiativeValidationError(
        422,
        'FORBIDDEN_TRANSITION',
        `Transition from '${initiative.status}' to '${input.newStatus}' is not allowed`
      );
    }

    // Reason required?
    if (check.requiresReason) {
      if (!input.reason || input.reason.trim().length === 0) {
        throw new InitiativeValidationError(
          400,
          'REASON_REQUIRED',
          `A reason is required for the '${initiative.status}' -> '${input.newStatus}' transition`
        );
      }
    }

    const now = new Date();

    // Update initiative status + updatedAt
    await tx`
      UPDATE app.initiative
      SET status = ${input.newStatus}, "updatedAt" = ${now}
      WHERE id = ${initiativeId} AND "projectId" = ${projectId}
    `;

    // Write StatusHistory row atomically
    const historyRows = await tx<{ id: string }[]>`
      INSERT INTO app.status_history
        ("projectId", "entityType", "entityId", "previousStatus", "newStatus", reason, actor)
      VALUES
        (${projectId}, 'initiative', ${initiativeId}, ${initiative.status}, ${input.newStatus}, ${input.reason ?? null}, ${resolveActor()})
      RETURNING id
    `;
    const statusHistoryId = historyRows[0]!.id;

    // Fetch updated initiative
    const updatedRows = await tx<InitiativeRow[]>`
      SELECT ${tx.unsafe(SELECT_COLS)}
      FROM app.initiative
      WHERE id = ${initiativeId} AND "projectId" = ${projectId}
    `;

    return { initiative: updatedRows[0]!, statusHistoryId };
  });
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

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
