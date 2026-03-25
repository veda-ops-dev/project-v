/**
 * routes/projects.ts
 *
 * Project V /api/projects route family.
 *
 * Authority: docs/api/projects-api.md
 *            docs/api/api-conventions.md
 *
 * This module is a thin routing layer.
 * All business logic lives in services/project.ts.
 * Validation of domain rules lives in services/project.ts and enforcement helpers.
 * This module:
 *   - parses and type-checks HTTP inputs
 *   - delegates to the service
 *   - maps service errors to HTTP responses via handleProjectServiceError
 *
 * Routes:
 *   GET    /api/projects
 *   GET    /api/projects/:projectId
 *   POST   /api/projects
 *   PATCH  /api/projects/:projectId
 *   POST   /api/projects/:projectId/status
 */

import type { FastifyInstance, FastifyRequest } from 'fastify';
import {
  listProjects,
  getProject,
  createProject,
  updateProject,
  transitionProjectStatus,
} from '../services/project.js';
import { sendError, handleProjectServiceError } from '../lib/errors.js';

// ── Allowed query/body field sets ────────────────────────────────────────────

const ALLOWED_LIST_PARAMS = new Set(['status', 'limit', 'cursor']);
const ALLOWED_CREATE_FIELDS = new Set(['key', 'name', 'description']);
const ALLOWED_PATCH_FIELDS = new Set(['name', 'description']);
const ALLOWED_STATUS_FIELDS = new Set(['newStatus', 'reason']);

// ── Route registration ───────────────────────────────────────────────────────

export async function projectRoutes(app: FastifyInstance): Promise<void> {

  // ── GET /api/projects ──────────────────────────────────────────────────────
  app.get('/api/projects', async (req: FastifyRequest, reply) => {
    const query = req.query as Record<string, unknown>;

    // Unknown query parameter check (api-conventions.md: Unknown Query Parameter Rule)
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

    try {
      const result = await listProjects({
        status: query['status'] !== undefined ? String(query['status']) : undefined,
        limit,
        cursor: query['cursor'] !== undefined ? String(query['cursor']) : undefined,
      });
      return reply.send(result);
    } catch (err) {
      if (handleProjectServiceError(err, reply)) return;
      throw err;
    }
  });

  // ── GET /api/projects/:projectId ───────────────────────────────────────────
  app.get('/api/projects/:projectId', async (req: FastifyRequest, reply) => {
    const { projectId } = req.params as { projectId: string };

    if (!isValidUuid(projectId)) {
      return sendError(reply, 400, 'INVALID_ID', 'projectId must be a valid UUID');
    }

    try {
      const project = await getProject(projectId);
      return reply.send(project);
    } catch (err) {
      if (handleProjectServiceError(err, reply)) return;
      throw err;
    }
  });

  // ── POST /api/projects ─────────────────────────────────────────────────────
  app.post('/api/projects', async (req: FastifyRequest, reply) => {
    const body = req.body as Record<string, unknown> | null ?? {};

    // Reject unknown fields (per PATCH Unknown Fields Rule — applied to POST as well for clean posture)
    for (const key of Object.keys(body)) {
      if (!ALLOWED_CREATE_FIELDS.has(key)) {
        return sendError(reply, 400, 'UNKNOWN_FIELD', `Unknown field: ${key}`);
      }
    }

    // Reject caller-supplied status
    if ('status' in body) {
      return sendError(reply, 400, 'FORBIDDEN_FIELD', 'status must not be supplied on creation; server assigns active');
    }

    try {
      const project = await createProject({
        key: body['key'] as string,
        name: body['name'] as string,
        description: body['description'] as string | null | undefined,
      });
      return reply.status(201).send(project);
    } catch (err) {
      if (handleProjectServiceError(err, reply)) return;
      throw err;
    }
  });

  // ── PATCH /api/projects/:projectId ────────────────────────────────────────
  app.patch('/api/projects/:projectId', async (req: FastifyRequest, reply) => {
    const { projectId } = req.params as { projectId: string };

    if (!isValidUuid(projectId)) {
      return sendError(reply, 400, 'INVALID_ID', 'projectId must be a valid UUID');
    }

    const body = req.body as Record<string, unknown> | null ?? {};

    // Reject unknown fields (api-conventions.md: PATCH Body Unknown Fields Rule)
    for (const key of Object.keys(body)) {
      if (!ALLOWED_PATCH_FIELDS.has(key)) {
        return sendError(reply, 400, 'UNKNOWN_FIELD', `Unknown field in PATCH body: ${key}`);
      }
    }

    try {
      const project = await updateProject(projectId, {
        name: body['name'] !== undefined ? String(body['name']) : undefined,
        description: body['description'] !== undefined
          ? (body['description'] === null ? null : String(body['description']))
          : undefined,
      });
      return reply.send(project);
    } catch (err) {
      if (handleProjectServiceError(err, reply)) return;
      throw err;
    }
  });

  // ── POST /api/projects/:projectId/status ──────────────────────────────────
  app.post('/api/projects/:projectId/status', async (req: FastifyRequest, reply) => {
    const { projectId } = req.params as { projectId: string };

    if (!isValidUuid(projectId)) {
      return sendError(reply, 400, 'INVALID_ID', 'projectId must be a valid UUID');
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
      const result = await transitionProjectStatus(projectId, {
        newStatus: String(body['newStatus']),
        reason: body['reason'] !== undefined ? String(body['reason']) : null,
      });
      return reply.send({
        ...result.project,
        statusHistoryId: result.statusHistoryId,
      });
    } catch (err) {
      if (handleProjectServiceError(err, reply)) return;
      throw err;
    }
  });
}

// ── Helpers ──────────────────────────────────────────────────────────────────

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isValidUuid(value: string): boolean {
  return UUID_REGEX.test(value);
}
