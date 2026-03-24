# Dependencies API

## Purpose

This document defines the Project V `dependencies` endpoint family.

It exists to answer:

```text
How are project-scoped dependency records listed, retrieved, created, and updated without allowing illegal cross-project links or vague sequencing logic?
```

Read this with:

- `docs/api/api-conventions.md`
- `docs/api/endpoint-governance.md`
- `docs/architecture/data/schema-authority.md`
- `docs/architecture/data/schema-specification.md`
- `docs/architecture/data/controlled-vocabularies.md`
- `docs/architecture/data/polymorphic-reference-enforcement.md`

---

## Family Scope

This family manages project-scoped Dependency records.

Dependencies are explicit sequencing records inside Project V.
They must not become a vague note-taking substitute, and they must not connect records across projects unless a later ADR explicitly introduces a bounded exception.

---

## Route Family

### `GET /api/projects/:projectId/dependencies`
List dependencies for one project.

### `GET /api/projects/:projectId/dependencies/:dependencyId`
Get one dependency.

### `POST /api/projects/:projectId/dependencies`
Create a dependency.

### `PATCH /api/projects/:projectId/dependencies/:dependencyId`
Update bounded mutable dependency fields.

No delete route exists in the first pass.

---

## Scope Rules

- every route is project-scoped
- `dependencyId` alone must not bypass project ownership rules
- both source and target entities must belong to the same project
- cross-project existence leakage is forbidden by default
- if a source or target entity is not found inside the project scope, the dependency creation must fail deterministically

---

## `GET /api/projects/:projectId/dependencies`

### Query parameters
Allowed first-pass filters:

- `sourceEntityType`
- `sourceEntityId`
- `targetEntityType`
- `targetEntityId`
- `dependencyType`
- `status`
- `limit`
- `cursor`

### Ordering
Default ordering should be deterministic:

```text
updatedAt desc, id asc
```

### Response shape
Each item should expose at least:

- `id`
- `projectId`
- `sourceEntityType`
- `sourceEntityId`
- `targetEntityType`
- `targetEntityId`
- `dependencyType`
- `status`
- `rationale`
- `createdAt`
- `updatedAt`

---

## `GET /api/projects/:projectId/dependencies/:dependencyId`

### Failure posture
- `404` if the dependency does not belong to the project or does not exist
- `400` for malformed identifiers

---

## `POST /api/projects/:projectId/dependencies`

### Required input
- `sourceEntityType`
- `sourceEntityId`
- `targetEntityType`
- `targetEntityId`
- `dependencyType`

### Optional input
- `rationale`

### Validation
- both source and target entities must exist inside the same project
- source entity type must be a governed allowed value: `objective`, `initiative`, `work_item`, `handoff`
- target entity type must be a governed allowed value: `objective`, `initiative`, `work_item`, `handoff`
- polymorphic references must be resolved using the central resolver defined in `docs/architecture/data/polymorphic-reference-enforcement.md`
- source and target must not be identical in both type and id
- `dependencyType` must use controlled vocabulary
- duplicate logical dependencies must fail deterministically; the unique index on `(projectId, sourceEntityType, sourceEntityId, targetEntityType, targetEntityId, dependencyType)` is enforced without exception
- illegal cross-project links must fail deterministically

### Initial status
The server assigns `status = active` on creation. Callers must not supply a `status` field at creation. Supplying one must fail with `400 Bad Request`.

### Response
- `201 Created` with canonical dependency record

---

## `PATCH /api/projects/:projectId/dependencies/:dependencyId`

### Allowed mutable fields
- `status`
- `rationale`

### Forbidden first-pass mutations
- changing `projectId`
- changing canonical `id`
- changing source entity identity
- changing target entity identity
- silently reshaping one dependency into a different dependency

### Validation
- `status` must use controlled vocabulary (`active`, `resolved`)
- `status` transitions must follow the governed one-way rule: `active -> resolved` only. The reverse (`resolved -> active`) is forbidden in the first pass and must fail deterministically.

### Status transition exception note
Dependency status is mutated through PATCH rather than a dedicated `/status` route. This is an intentional exception to the pattern used by Objective, Initiative, WorkItem, and Handoff. The rationale is that dependency lifecycle has only one allowed forward transition (`active -> resolved`) and no reason requirement. The full transition enforcement logic still applies: the same rules defined in `status-transitions.md` for dependencies are enforced in the PATCH handler.

### Response
- `200 OK` with updated canonical dependency record

---

## Controlled Vocabularies

Allowed values are governed by:

- `docs/architecture/data/controlled-vocabularies.md`

Relevant vocabularies:

- dependency type
- dependency status

---

## Error Posture

First-pass expected error classes:

- `400 Bad Request` for malformed input or caller-supplied forbidden fields (e.g., `status` at creation)
- `404 Not Found` for missing or out-of-scope project-scoped records
- `409 Conflict` for duplicate logical dependencies (same source, target, and dependency type within a project)
- `422 Unprocessable Entity` for semantically invalid but well-formed input

Use the common Project V error body shape governed by `docs/api/api-conventions.md`.

---

## Hammer Expectations

This family should be hammered for:

- same-project source and target enforcement
- illegal cross-project dependency rejection
- deterministic listing
- duplicate dependency rejection (409)
- invalid controlled-vocabulary rejection
- self-dependency rejection
- caller-supplied status at creation rejection
- forbidden reverse transition rejection (`resolved -> active`)

---

## Final Rule

The Dependencies API must keep sequencing explicit, project-safe, and bounded.
If it starts allowing ambiguous or cross-project dependency behavior, it is wrong.

