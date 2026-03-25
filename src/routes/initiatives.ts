/**
 * routes/initiatives.ts
 *
 * Project V /api/projects/:projectId/initiatives route family.
 *
 * Authority: docs/api/initiatives-api.md
 *            docs/api/api-conventions.md
 *
 * This module is a thin routing layer.
 * All business logic lives in services/initiative.ts.
 * Validation of domain rules lives in services/initiative.ts and enforcement helpers.
 * This module:
 *   - parses and type-checks HTTP inputs
 *   - delegates to the service
 *   - maps service errors to HTTP responses via handleInitiativeServiceError
 *
 * Routes:
 *   GET    /api/projects/:projectId/initiatives
 *   GET    /api/projects/:projectId/initiatives/:initiativeId
 *   POST   /api/projects/:projectId/initiatives
 *   PATCH  /api/projects/:projectId/initiatives/:initiativeId
 *   POST   /api/projects/:projectId/initiatives/:initiativeId/status
 */

import type { FastifyInstance, FastifyRequest } from 'fastify';
import {
  listInitiatives,
  getInitiative,
  createInitiative,
  updateInitiative,
  transitionInitiativeStatus,
} from '../services/initiative.js';
import { sendError, handleInitiativeServiceError } from '../lib/errors.js';

// ── Allowed query/body field sets ────────────────────────────────────────────

const ALLOWED_LIST_PARAMS = new Set(['status', 'priority', 'objectiveId', 'targetSystem', 'limit', 'cursor']);
const ALLOWED_CREATE_FIELDS = new Set(['key', 'title', 'description', 'objectiveId', 'priority', 'targetSystem']);
const ALLOWED_PATCH_FIELDS = new Set(['title', 'description', 'objectiveId', 'priority', 'targetSystem']);
const ALLOWED_STATUS_FIELDS = new Set(['newStatus', 'reason']);

// ── Route registration ───────────────────────────────────────────────────────

export async function initiativeRoutes(app: FastifyInstance): Promise<void> {

  // ── GET /api/projects/:projectId/initiatives ───────────────────────────────
  app.get('/api/projects/:projectId/initiatives', async (req: FastifyRequest, reply) => {
    const { projectId } = req.params as { projectId: string };

    if (!isValidUuid(projectId)) {
      return sendError(reply, 400, 'INVALID_ID', 'projectId must be a valid UUID');
    }

    const query = req.query as Record<string, unknown>;

    // Unknown query parameter check
    for (const key of Object.keys(query)) {
      if (!ALLOWED_LIST_PARAMS.has(key)) {
        return sendError(reply, 400, 'UNKNOWN_QUERY_PARAM', `Unknown query parameter: ${key}`);
      }
    }

    const limit = query['limit'] !== undefined
      ? parseInt(String(query['limit']), 10)
      : undefined;

    if (limit !== undefined && (isNaN(limit) || limit < 1)) {
      return sendError(reply, 400, 'INVALID_LIMIT', 'limit must be a positive integer');
    }

    const priority = query['priority'] !== undefined
      ? parseInt(String(query['priority']), 10)
      : undefined;

    if (priority !== undefined && isNaN(priority)) {
      return sendError(reply, 400, 'INVALID_PRIORITY', 'priority must be an integer');
    }

    try {
      const result = await listInitiatives({
        projectId,
        status: query['status'] !== undefined ? String(query['status']) : undefined,
        priority,
        objectiveId: query['objectiveId'] !== undefined ? String(query['objectiveId']) : undefined,
        targetSystem: query['targetSystem'] !== undefined ? String(query['targetSystem']) : undefined,
        limit,
        cursor: query['cursor'] !== undefined ? String(query['cursor']) : undefined,
      });
      return reply.send(result);
    } catch (err) {
      if (handleInitiativeServiceError(err, reply)) return;
      throw err;
    }
  });

  // ── GET /api/projects/:projectId/initiatives/:initiativeId ─────────────────
  app.get('/api/projects/:projectId/initiatives/:initiativeId', async (req: FastifyRequest, reply) => {
    const { projectId, initiativeId } = req.params as { projectId: string; initiativeId: string };

    if (!isValidUuid(projectId)) {
      return sendError(reply, 400, 'INVALID_ID', 'projectId must be a valid UUID');
    }
    if (!isValidUuid(initiativeId)) {
      return sendError(reply, 400, 'INVALID_ID', 'initiativeId must be a valid UUID');
    }

    try {
      const initiative = await getInitiative(projectId, initiativeId);
      return reply.send(initiative);
    } catch (err) {
      if (handleInitiativeServiceError(err, reply)) return;
      throw err;
    }
  });

  // ── POST /api/projects/:projectId/initiatives ──────────────────────────────
  app.post('/api/projects/:projectId/initiatives', async (req: FastifyRequest, reply) => {
    const { projectId } = req.params as { projectId: string };

    if (!isValidUuid(projectId)) {
      return sendError(reply, 400, 'INVALID_ID', 'projectId must be a valid UUID');
    }

    const body = req.body as Record<string, unknown> | null ?? {};

    // Reject unknown fields
    for (const key of Object.keys(body)) {
      if (!ALLOWED_CREATE_FIELDS.has(key)) {
        return sendError(reply, 400, 'UNKNOWN_FIELD', `Unknown field: ${key}`);
      }
    }

    // Reject caller-supplied status (initiatives-api.md: server assigns proposed)
    if ('status' in body) {
      return sendError(reply, 400, 'FORBIDDEN_FIELD', 'status must not be supplied on creation; server assigns proposed');
    }

    // Required field checks
    if (!('key' in body)) {
      return sendError(reply, 400, 'MISSING_FIELD', 'key is required');
    }
    if (!('title' in body)) {
      return sendError(reply, 400, 'MISSING_FIELD', 'title is required');
    }

    try {
      const initiative = await createInitiative({
        projectId,
        key: String(body['key']),
        title: String(body['title']),
        description: body['description'] !== undefined
          ? (body['description'] === null ? null : String(body['description']))
          : undefined,
        objectiveId: body['objectiveId'] !== undefined
          ? (body['objectiveId'] === null ? null : String(body['objectiveId']))
          : undefined,
        priority: body['priority'] !== undefined
          ? Number(body['priority'])
          : undefined,
        targetSystem: body['targetSystem'] !== undefined
          ? (body['targetSystem'] === null ? null : String(body['targetSystem']))
          : undefined,
      });
      return reply.status(201).send(initiative);
    } catch (err) {
      if (handleInitiativeServiceError(err, reply)) return;
      throw err;
    }
  });

  // ── PATCH /api/projects/:projectId/initiatives/:initiativeId ───────────────
  app.patch('/api/projects/:projectId/initiatives/:initiativeId', async (req: FastifyRequest, reply) => {
    const { projectId, initiativeId } = req.params as { projectId: string; initiativeId: string };

    if (!isValidUuid(projectId)) {
      return sendError(reply, 400, 'INVALID_ID', 'projectId must be a valid UUID');
    }
    if (!isValidUuid(initiativeId)) {
      return sendError(reply, 400, 'INVALID_ID', 'initiativeId must be a valid UUID');
    }

    const body = req.body as Record<string, unknown> | null ?? {};

    // Reject unknown fields (including forbidden fields like key, projectId, id, status)
    for (const key of Object.keys(body)) {
      if (!ALLOWED_PATCH_FIELDS.has(key)) {
        return sendError(reply, 400, 'UNKNOWN_FIELD', `Unknown field in PATCH body: ${key}`);
      }
    }

    try {
      const initiative = await updateInitiative(projectId, initiativeId, {
        title: body['title'] !== undefined ? String(body['title']) : undefined,
        description: body['description'] !== undefined
          ? (body['description'] === null ? null : String(body['description']))
          : undefined,
        objectiveId: body['objectiveId'] !== undefined
          ? (body['objectiveId'] === null ? null : String(body['objectiveId']))
          : undefined,
        priority: body['priority'] !== undefined ? Number(body['priority']) : undefined,
        targetSystem: body['targetSystem'] !== undefined
          ? (body['targetSystem'] === null ? null : String(body['targetSystem']))
          : undefined,
      });
      return reply.send(initiative);
    } catch (err) {
      if (handleInitiativeServiceError(err, reply)) return;
      throw err;
    }
  });

  // ── POST /api/projects/:projectId/initiatives/:initiativeId/status ─────────
  app.post('/api/projects/:projectId/initiatives/:initiativeId/status', async (req: FastifyRequest, reply) => {
    const { projectId, initiativeId } = req.params as { projectId: string; initiativeId: string };

    if (!isValidUuid(projectId)) {
      return sendError(reply, 400, 'INVALID_ID', 'projectId must be a valid UUID');
    }
    if (!isValidUuid(initiativeId)) {
      return sendError(reply, 400, 'INVALID_ID', 'initiativeId must be a valid UUID');
    }

    const body = req.body as Record<string, unknown> | null ?? {};

    // Reject unknown fields
    for (const key of Object.keys(body)) {
      if (!ALLOWED_STATUS_FIELDS.has(key)) {
        return sendError(reply, 400, 'UNKNOWN_FIELD', `Unknown field: ${key}`);
      }
    }

    if (!('newStatus' in body)) {
      return sendError(reply, 400, 'MISSING_FIELD', 'newStatus is required');
    }

    try {
      const result = await transitionInitiativeStatus(projectId, initiativeId, {
        newStatus: String(body['newStatus']),
        reason: body['reason'] !== undefined ? String(body['reason']) : null,
      });
      return reply.send({
        ...result.initiative,
        statusHistoryId: result.statusHistoryId,
      });
    } catch (err) {
      if (handleInitiativeServiceError(err, reply)) return;
      throw err;
    }
  });
}

// ── Helpers ──────────────────────────────────────────────────────────────────

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isValidUuid(value: string): boolean {
  return UUID_REGEX.test(value);
}
