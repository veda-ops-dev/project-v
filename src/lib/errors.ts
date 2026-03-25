/**
 * lib/errors.ts
 *
 * Shared error response helpers.
 *
 * Authority: docs/api/api-conventions.md (Error Response Rule, Error Code Rule)
 *
 * All Project V error responses use the same body shape:
 *   { error: { code, message, details?, requestId? } }
 */

import type { FastifyReply } from 'fastify';
import {
  ProjectValidationError,
  ProjectNotFoundError,
  ProjectKeyConflictError,
} from '../services/project.js';
import {
  ObjectiveValidationError,
  ObjectiveNotFoundError,
  ObjectiveKeyConflictError,
} from '../services/objective.js';
import {
  InitiativeValidationError,
  InitiativeNotFoundError,
  InitiativeKeyConflictError,
} from '../services/initiative.js';

export interface ErrorBody {
  error: {
    code: string;
    message: string;
    details?: unknown;
  };
}

export function sendError(
  reply: FastifyReply,
  status: number,
  code: string,
  message: string,
  details?: unknown
): void {
  const body: ErrorBody = { error: { code, message } };
  if (details !== undefined) body.error.details = details;
  void reply.status(status).send(body);
}

/**
 * Map known Project service errors to HTTP responses.
 * Returns true if the error was handled; false if it should be re-thrown.
 */
export function handleProjectServiceError(err: unknown, reply: FastifyReply): boolean {
  if (err instanceof ProjectValidationError) {
    sendError(reply, err.statusCode, err.code, err.message);
    return true;
  }
  if (err instanceof ProjectNotFoundError) {
    sendError(reply, 404, 'NOT_FOUND', err.message);
    return true;
  }
  if (err instanceof ProjectKeyConflictError) {
    sendError(reply, 409, 'CONFLICT', err.message);
    return true;
  }
  return false;
}

/**
 * Map known Objective service errors to HTTP responses.
 * Returns true if the error was handled; false if it should be re-thrown.
 */
export function handleObjectiveServiceError(err: unknown, reply: FastifyReply): boolean {
  if (err instanceof ObjectiveValidationError) {
    sendError(reply, err.statusCode, err.code, err.message);
    return true;
  }
  if (err instanceof ObjectiveNotFoundError) {
    sendError(reply, 404, 'NOT_FOUND', err.message);
    return true;
  }
  if (err instanceof ObjectiveKeyConflictError) {
    sendError(reply, 409, 'CONFLICT', err.message);
    return true;
  }
  return false;
}

/**
 * Map known Initiative service errors to HTTP responses.
 * Returns true if the error was handled; false if it should be re-thrown.
 *
 * Also handles ProjectNotFoundError because the Initiative service can throw
 * it when the parent project does not exist (e.g. list or create with a
 * missing projectId). This is semantically correct: the missing entity is
 * the project, not the initiative.
 */
export function handleInitiativeServiceError(err: unknown, reply: FastifyReply): boolean {
  if (err instanceof InitiativeValidationError) {
    sendError(reply, err.statusCode, err.code, err.message);
    return true;
  }
  if (err instanceof InitiativeNotFoundError) {
    sendError(reply, 404, 'NOT_FOUND', err.message);
    return true;
  }
  if (err instanceof ProjectNotFoundError) {
    sendError(reply, 404, 'NOT_FOUND', err.message);
    return true;
  }
  if (err instanceof InitiativeKeyConflictError) {
    sendError(reply, 409, 'CONFLICT', err.message);
    return true;
  }
  return false;
}
