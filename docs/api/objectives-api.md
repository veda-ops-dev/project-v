# Objectives API

## Purpose

This document defines the Project V `objectives` endpoint family.

It exists to answer:

```text
How are project-scoped objectives listed, retrieved, created, and updated without weakening explicit project ownership?
```

Read this with:

- `docs/api/api-conventions.md`
- `docs/api/endpoint-governance.md`
- `docs/architecture/data/schema-authority.md`
- `docs/architecture/data/schema-specification.md`

---

## Family Scope

This family manages project-scoped Objective records.

Objectives are always project-scoped.
No objective route may operate without explicit project context.

---

## Route Family

### `GET /api/projects/:projectId/objectives`
List objectives for one project.

### `GET /api/projects/:projectId/objectives/:objectiveId`
Get one objective inside one project.

### `POST /api/projects/:projectId/objectives`
Create an objective inside one project.

### `PATCH /api/projects/:projectId/objectives/:objectiveId`
Update bounded mutable objective fields.

### `POST /api/projects/:projectId/objectives/:objectiveId/status`
Execute an explicit status transition for an objective.

No delete route exists in the first pass.

---

## Scope Rules

- every read and write is project-scoped
- `objectiveId` alone must not bypass project ownership rules
- if an objective exists under another project, the route must behave as unavailable
- cross-project existence leakage is forbidden by default

---

## `GET /api/projects/:projectId/objectives`

### Purpose
Return the bounded objective list for one project.

### Query parameters
Allowed first-pass filters:

- `status`
- `priority`
- `limit`
- `cursor`

### Ordering
Default ordering should be deterministic:

```text
priority asc, updatedAt desc, id asc
```

### Response shape
Each item should expose at least:

- `id`
- `projectId`
- `key`
- `title`
- `description`
- `status`
- `priority`
- `targetStartAt`
- `targetEndAt`
- `createdAt`
- `updatedAt`

---

## `GET /api/projects/:projectId/objectives/:objectiveId`

### Purpose
Return one bounded objective.

### Failure posture
- `404` if the project does not exist or the objective does not belong to that project
- `400` for malformed identifiers

---

## `POST /api/projects/:projectId/objectives`

### Required input
- `key`
- `title`

### Optional input
- `description`
- `priority`
- `targetStartAt`
- `targetEndAt`

### Initial status
The server assigns `status = proposed` on creation. Callers must not supply a `status` field at creation. Supplying one must fail with `400 Bad Request`.

### Validation
- `projectId` must reference a real project and must not be archived; creation under an archived project must fail with `422 Unprocessable Entity`
- `key` must be unique within the project
- `title` must be non-empty
- `priority`, if supplied, must be an integer in the range `1..1000`; lower values represent higher priority (see `docs/architecture/data/controlled-vocabularies.md`)
- target dates must be chronologically valid if both are supplied

### Response
- `201 Created` with canonical objective record

---

## `PATCH /api/projects/:projectId/objectives/:objectiveId`

### Allowed mutable fields
- `title`
- `description`
- `priority`
- `targetStartAt`
- `targetEndAt`

### Forbidden first-pass mutations
- changing `projectId`
- changing canonical `id`
- hidden cross-project reassignment
- silent status transition through a generic patch if explicit status routes are used

Attempting to supply a forbidden field in a PATCH body must fail with `400 Bad Request`.

### Response
- `200 OK` with updated canonical objective record

---

## `POST /api/projects/:projectId/objectives/:objectiveId/status`

### Purpose
Perform a governed objective status transition.

### Required input
- `newStatus`
- `reason` — required for the following transitions: `active -> archived`, `blocked -> archived`, `proposed -> archived`. Optional for all other allowed transitions.

### Validation
- `newStatus` must use controlled vocabulary (`proposed`, `active`, `blocked`, `completed`, `archived`)
- only transitions defined as allowed in `docs/architecture/data/status-transitions.md` are accepted; all others must fail deterministically with `422 Unprocessable Entity`
- `reason` must be non-empty when required for the transition; a missing or empty reason on a required-reason transition must fail with `400 Bad Request`
- all objective status transitions must write a `StatusHistory` row atomically in the same transaction

### Response
- `200 OK` with updated objective record and status-history confirmation fields

---

## Status Vocabulary

The exact enum should align to the schema specification.
A small first-pass vocabulary is preferred.

Recommended initial values:

- `proposed`
- `active`
- `blocked`
- `completed`
- `archived`

---

## Error Posture

First-pass expected error classes:

- `400 Bad Request` for malformed input
- `404 Not Found` for missing project or objective
- `409 Conflict` for duplicate `key` within the project
- `422 Unprocessable Entity` for semantically invalid but well-formed input

Use the common Project V error body shape governed by `docs/api/api-conventions.md`.

---

## Hammer Expectations

This family should be hammered for:

- project-scope enforcement
- per-project key uniqueness
- duplicate key rejection (409)
- deterministic listing
- illegal cross-project read rejection
- illegal status transition rejection (all forbidden transitions fail with `422`)
- missing required `reason` rejection for archival transitions
- `StatusHistory` row written for every status transition

---

## Final Rule

The Objectives API is project-scoped by design.
Every route must keep ownership, ordering, and mutation discipline explicit.
