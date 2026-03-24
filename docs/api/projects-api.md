# Projects API

## Purpose

This document defines the Project V `projects` endpoint family.

It exists to answer:

```text
How are Project records listed, retrieved, created, and updated without weakening multi-project discipline or bounded ownership?
```

Read this with:

- `docs/api/api-conventions.md`
- `docs/api/endpoint-governance.md`
- `docs/architecture/data/schema-authority.md`
- `docs/architecture/data/schema-specification.md`
- `docs/architecture/data/status-transitions.md`

---

## Family Scope

This family manages the Project V planning anchor records.

It does not expose:

- VEDA project truth
- V Forge project truth
- cross-system convenience state

---

## Route Family

### `GET /api/projects`
List projects.

### `GET /api/projects/:projectId`
Get a single project.

### `POST /api/projects`
Create a project.

### `PATCH /api/projects/:projectId`
Update bounded mutable non-status project fields.

### `POST /api/projects/:projectId/status`
Execute an explicit status transition for a project.

No delete route exists in the first pass.
Project archival or lifecycle closure should be handled by explicit status transitions, not destructive deletion.

---

## Scope Rules

Projects are top-level orchestration anchors.

Because this family manages the project anchor itself:

- list routes may return multiple projects
- single-project routes resolve by `projectId`
- mutation routes must target one explicit project record

A project key is globally unique inside Project V.

---

## `GET /api/projects`

### Purpose
Return a deterministic list of Project V projects.

### Query parameters
Allowed first-pass query parameters:

- `status`
- `limit`
- `cursor`

### Ordering
Default ordering should be deterministic:

```text
updatedAt desc, id asc
```

If a different ordering is introduced, it must remain explicit and stable.

### Response shape
Each item should expose at least:

- `id`
- `key`
- `name`
- `status`
- `description`
- `createdAt`
- `updatedAt`

### Validation
- unknown query parameters must fail with `400 Bad Request`; unrecognized filter fields are not silently ignored
- limit must remain bounded

---

## `GET /api/projects/:projectId`

### Purpose
Return one project anchor record.

### Response shape
Return the bounded canonical fields for the project.

### Failure posture
- `404` if the project does not exist
- `400` for malformed identifiers

---

## `POST /api/projects`

### Purpose
Create a new Project V project anchor.

### Required input
- `key`
- `name`

### Optional input
- `description`

### Initial status
The server assigns `status = active` on creation. Callers must not supply a `status` field at creation. Supplying one must fail with `400 Bad Request`.

### Validation
- `key` must be unique globally inside Project V
- `key` must conform to the governed key format
- `name` must be non-empty
- unknown enum values must fail deterministically

### Mutation rule
Project creation must be atomic.
If companion records are created later as part of bootstrap, that should happen through an explicit bootstrapping path rather than hidden side effects here.

### Response
- `201 Created` with the canonical project record

---

## `PATCH /api/projects/:projectId`

### Purpose
Update bounded mutable non-status fields on a project.

### Allowed mutable fields in the first pass
- `name`
- `description`

### Forbidden first-pass mutations
- changing canonical `id`
- reassigning the project identity to another record
- changing `status` through generic patch
- hidden cross-system writes

### Response
- `200 OK` with updated canonical project record

---

## `POST /api/projects/:projectId/status`

### Required input
- `newStatus`
- `reason` — required for the following transitions: `active -> archived`, `deferred -> archived`. Optional for all other allowed transitions.

### Validation
- `newStatus` must use controlled vocabulary (`active`, `deferred`, `archived`)
- only transitions defined as allowed in `docs/architecture/data/status-transitions.md` are accepted; all others must fail deterministically with `422 Unprocessable Entity`
- `reason` must be non-empty when required for the transition; a missing or empty reason on a required-reason transition must fail with `400 Bad Request`
- all project status transitions must write a `StatusHistory` row atomically in the same transaction

### Response
- `200 OK` with updated project record and status-history confirmation fields

---

## Error Posture

First-pass expected error classes:

- `400 Bad Request` for malformed input or unrecognized query parameters
- `404 Not Found` for missing project
- `409 Conflict` for duplicate `key`
- `422 Unprocessable Entity` for semantically invalid but well-formed input

Use the common Project V error body shape governed by `docs/api/api-conventions.md`.

---

## Status Vocabulary

The exact enum should remain aligned to the schema specification.
A small first-pass vocabulary is preferred.

Recommended initial values:

- `active`
- `deferred`
- `archived`

---

## Hammer Expectations

This family should be hammered for:

- deterministic listing
- duplicate key rejection
- malformed identifier rejection
- invalid status rejection
- illegal project-status transition rejection (all forbidden transitions fail with `422`)
- missing required `reason` rejection for archival transitions
- `StatusHistory` row written for every status transition
- stable response shape

---

## Final Rule

The Projects API manages Project V's own project anchors only.
It must stay boring, deterministic, and bounded.
