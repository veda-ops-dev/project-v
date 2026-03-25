/**
 * routes/objectives.ts
 *
 * Project V /api/projects/:projectId/objectives route family.
 *
 * Authority: docs/api/objectives-api.md
 *            docs/api/api-conventions.md
 *
 * This module is a thin routing layer.
 * All business logic lives in services/objective.ts.
 * Validation of domain rules lives in services/objective.ts and enforcement helpers.
 * This module:
 *   - parses and type-checks HTTP inputs
 *   - delegates to the service
 *   - maps service errors to HTTP responses via handleObjectiveServiceError
 *
 * Routes:
 *   GET    /api/projects/:projectId/objectives
 *   GET    /api/projects/:projectId/objectives/:objectiveId
 *   POST   /api/projects/:projectId/objectives
 *   PATCH  /api/projects/:projectId/objectives/:objectiveId
 *   POST   /api/projects/:projectId/objectives/:objectiveId/status
 */

import type { FastifyInstance, FastifyRequest } from 'fastify';
import {
  listObjectives,
  getObjective,
  createObjective,
  updateObjective,
  transitionObjectiveStatus,
} from '../services/objective.js';
import { sendError, handleObjectiveServiceError } from '../lib/errors.js';

// ── Allowed query/body field sets ────────────────────────────────────────────

const ALLOWED_LIST_PARAMS = new Set(['status', 'priority', 'limit', 'cursor']);
const ALLOWED_CREATE_FIELDS = new Set(['key', 'title', 'description', 'priority', 'targetStartAt', 'targetEndAt']);
const ALLOWED_PATCH_FIELDS = new Set(['title', 'description', 'priority', 'targetStartAt', 'targetEndAt']);
const ALLOWED_STATUS_FIELDS = new Set(['newStatus', 'reason']);

// ── Route registration ───────────────────────────────────────────────────────

export async function objectiveRoutes(app: FastifyInstance): Promise<void> {

  // ── GET /api/projects/:projectId/objectives ────────────────────────────────
  app.get('/api/projects/:projectId/objectives', async (req: FastifyRequest, reply) => {
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
      const result = await listObjectives({
        projectId,
        status: query['status'] !== undefined ? String(query['status']) : undefined,
        priority,
        limit,
        cursor: query['cursor'] !== undefined ? String(query['cursor']) : undefined,
      });
      return reply.send(result);
    } catch (err) {
      if (handleObjectiveServiceError(err, reply)) return;
      throw err;
    }
  });

  // ── GET /api/projects/:projectId/objectives/:objectiveId ───────────────────
  app.get('/api/projects/:projectId/objectives/:objectiveId', async (req: FastifyRequest, reply) => {
    const { projectId, objectiveId } = req.params as { projectId: string; objectiveId: string };

    if (!isValidUuid(projectId)) {
      return sendError(reply, 400, 'INVALID_ID', 'projectId must be a valid UUID');
    }
    if (!isValidUuid(objectiveId)) {
      return sendError(reply, 400, 'INVALID_ID', 'objectiveId must be a valid UUID');
    }

    try {
      const objective = await getObjective(projectId, objectiveId);
      return reply.send(objective);
    } catch (err) {
      if (handleObjectiveServiceError(err, reply)) return;
      throw err;
    }
  });

  // ── POST /api/projects/:projectId/objectives ───────────────────────────────
  app.post('/api/projects/:projectId/objectives', async (req: FastifyRequest, reply) => {
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

    // Reject caller-supplied status (objectives-api.md: server assigns proposed)
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
      const objective = await createObjective({
        projectId,
        key: String(body['key']),
        title: String(body['title']),
        description: body['description'] !== undefined
          ? (body['description'] === null ? null : String(body['description']))
          : undefined,
        priority: body['priority'] !== undefined
          ? Number(body['priority'])
          : undefined,
        targetStartAt: body['targetStartAt'] !== undefined
          ? (body['targetStartAt'] === null ? null : String(body['targetStartAt']))
          : undefined,
        targetEndAt: body['targetEndAt'] !== undefined
          ? (body['targetEndAt'] === null ? null : String(body['targetEndAt']))
          : undefined,
      });
      return reply.status(201).send(objective);
    } catch (err) {
      if (handleObjectiveServiceError(err, reply)) return;
      throw err;
    }
  });

  // ── PATCH /api/projects/:projectId/objectives/:objectiveId ─────────────────
  app.patch('/api/projects/:projectId/objectives/:objectiveId', async (req: FastifyRequest, reply) => {
    const { projectId, objectiveId } = req.params as { projectId: string; objectiveId: string };

    if (!isValidUuid(projectId)) {
      return sendError(reply, 400, 'INVALID_ID', 'projectId must be a valid UUID');
    }
    if (!isValidUuid(objectiveId)) {
      return sendError(reply, 400, 'INVALID_ID', 'objectiveId must be a valid UUID');
    }

    const body = req.body as Record<string, unknown> | null ?? {};

    // Reject unknown fields (including forbidden fields like key, projectId, id, status)
    for (const key of Object.keys(body)) {
      if (!ALLOWED_PATCH_FIELDS.has(key)) {
        return sendError(reply, 400, 'UNKNOWN_FIELD', `Unknown field in PATCH body: ${key}`);
      }
    }

    try {
      const objective = await updateObjective(projectId, objectiveId, {
        title: body['title'] !== undefined ? String(body['title']) : undefined,
        description: body['description'] !== undefined
          ? (body['description'] === null ? null : String(body['description']))
          : undefined,
        priority: body['priority'] !== undefined ? Number(body['priority']) : undefined,
        targetStartAt: body['targetStartAt'] !== undefined
          ? (body['targetStartAt'] === null ? null : String(body['targetStartAt']))
          : undefined,
        targetEndAt: body['targetEndAt'] !== undefined
          ? (body['targetEndAt'] === null ? null : String(body['targetEndAt']))
          : undefined,
      });
      return reply.send(objective);
    } catch (err) {
      if (handleObjectiveServiceError(err, reply)) return;
      throw err;
    }
  });

  // ── POST /api/projects/:projectId/objectives/:objectiveId/status ───────────
  app.post('/api/projects/:projectId/objectives/:objectiveId/status', async (req: FastifyRequest, reply) => {
    const { projectId, objectiveId } = req.params as { projectId: string; objectiveId: string };

    if (!isValidUuid(projectId)) {
      return sendError(reply, 400, 'INVALID_ID', 'projectId must be a valid UUID');
    }
    if (!isValidUuid(objectiveId)) {
      return sendError(reply, 400, 'INVALID_ID', 'objectiveId must be a valid UUID');
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
      const result = await transitionObjectiveStatus(projectId, objectiveId, {
        newStatus: String(body['newStatus']),
        reason: body['reason'] !== undefined ? String(body['reason']) : null,
      });
      return reply.send({
        ...result.objective,
        statusHistoryId: result.statusHistoryId,
      });
    } catch (err) {
      if (handleObjectiveServiceError(err, reply)) return;
      throw err;
    }
  });
}

// ── Helpers ──────────────────────────────────────────────────────────────────

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isValidUuid(value: string): boolean {
  return UUID_REGEX.test(value);
}
