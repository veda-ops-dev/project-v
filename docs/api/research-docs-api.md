# Research Docs API

## Purpose

This document defines the Project V `research-docs` endpoint family.

It exists to answer:

```text
How are project-scoped research documents listed, retrieved, created, and updated without confusing planning-support research with observatory ownership?
```

Read this with:

- `docs/api/api-conventions.md`
- `docs/api/endpoint-governance.md`
- `docs/architecture/integrations/veda-integration.md`
- `docs/architecture/data/schema-authority.md`
- `docs/architecture/data/schema-specification.md`
- `docs/architecture/data/status-transitions.md`
- `docs/architecture/data/controlled-vocabularies.md`

---

## Family Scope

This family manages project-scoped ResearchDoc records.

Research docs support planning and orchestration.
They do not make Project V the owner of observatory truth.

---

## Route Family

### `GET /api/projects/:projectId/research-docs`
List research docs for one project.

### `GET /api/projects/:projectId/research-docs/:researchDocId`
Get one research doc.

### `POST /api/projects/:projectId/research-docs`
Create a research doc record.

### `PATCH /api/projects/:projectId/research-docs/:researchDocId`
Update bounded mutable research-doc fields.

No delete route exists in the first pass.

---

## Scope Rules

- every route is project-scoped
- `researchDocId` alone must not bypass project ownership rules
- cross-project existence leakage is forbidden by default
- imported observatory material must remain visibly imported or external rather than masquerading as canonical Project V truth

---

## `GET /api/projects/:projectId/research-docs`

### Query parameters
Allowed first-pass filters:

- `status`
- `sourceType`
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
- `title`
- `sourceType`
- `storageLocator`
- `status`
- `summary`
- `createdAt`
- `updatedAt`

---

## `GET /api/projects/:projectId/research-docs/:researchDocId`

### Failure posture
- `404` if the research doc does not belong to the project or does not exist
- `400` for malformed identifiers

---

## `POST /api/projects/:projectId/research-docs`

### Required input
- `title`
- `sourceType`
- `storageLocator`
- `status`

### Optional input
- `summary`

### Caller-supplied status exception
Research docs require the caller to supply `status` at creation. This is an intentional exception to the pattern used by Objective, Initiative, WorkItem, and Handoff, where initial status is always server-assigned. The rationale is that research docs may arrive in different lifecycle states depending on their origin — an imported doc may be created directly as `active`, while a stub record under active drafting may warrant a different starting state. The caller remains responsible for supplying a valid governed value.

### Validation
- `title` must be non-empty
- `storageLocator` must be non-empty; no format is enforced in the first pass — locators may be URLs, file paths, or other reference identifiers
- existence of the storage location is not validated; Project V does not make outbound calls to resolve storage references (see External Reference Validation Rule in `docs/api/api-conventions.md`)
- staleness of the storage location is the caller's responsibility
- `sourceType` must use controlled vocabulary
- `status` must use controlled vocabulary; an unknown value must fail with `422 Unprocessable Entity`

### Response
- `201 Created` with canonical research-doc record

---

## `PATCH /api/projects/:projectId/research-docs/:researchDocId`

### Allowed mutable fields
- `title`
- `status`
- `summary`
- `storageLocator`

### Forbidden first-pass mutations
- changing `projectId`
- changing canonical `id`
- silently converting imported/external provenance into canonical Project V ownership claims

### Validation
- `storageLocator`, if supplied, must be non-empty; no format is enforced in the first pass
- existence of the storage location is not validated; Project V does not make outbound calls to resolve storage references (see External Reference Validation Rule in `docs/api/api-conventions.md`)
- staleness of the storage location is the caller's responsibility
- `status` must use controlled vocabulary (`active`, `archived`)
- `status` transitions must follow the governed one-way rule: `active -> archived` only. The reverse (`archived -> active`) is forbidden in the first pass and must fail deterministically.

### Status transition exception note
Research doc status is mutated through PATCH rather than a dedicated `/status` route. This is an intentional exception to the pattern used by Objective, Initiative, WorkItem, and Handoff. The rationale is that research doc lifecycle has only one allowed forward transition (`active -> archived`) and no history record requirement.

The `active -> archived` transition requires an explicit non-empty `reason` field in the PATCH body. Omitting `reason` when transitioning to `archived` must fail with `400 Bad Request`. This aligns with the requirement in `docs/architecture/data/status-transitions.md`.

The forbidden reverse transition (`archived -> active`) must be rejected with `422 Unprocessable Entity`.

### Response
- `200 OK` with updated canonical research-doc record

---

## Hammer Expectations

This family should be hammered for:

- project-scope enforcement
- deterministic listing
- invalid identifier rejection
- non-empty storage-locator enforcement
- provenance honesty for imported/external material
- illegal research-doc transition rejection

---

## Final Rule

The Research Docs API manages planning-support research records only.
It must not become a disguised observatory surface.
