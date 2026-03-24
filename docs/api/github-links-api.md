# GitHub Links API

## Purpose

This document defines the Project V `github-links` endpoint family.

It exists to answer:

```text
How are project-scoped GitHub linkage records listed, retrieved, created, and updated so implementation traceability stays explicit without turning Project V into a GitHub clone?
```

Read this with:

- `docs/api/api-conventions.md`
- `docs/api/endpoint-governance.md`
- `docs/architecture/core/implementation-traceability.md`
- `docs/architecture/data/github-linkage-model.md`
- `docs/architecture/data/code-linkage-and-code-visibility.md`
- `docs/architecture/integrations/github-integration.md`
- `docs/architecture/data/schema-authority.md`
- `docs/architecture/data/schema-specification.md`
- `docs/architecture/data/controlled-vocabularies.md`
- `docs/architecture/data/polymorphic-reference-enforcement.md`

---

## Family Scope

This family manages project-scoped `GitHubLink` records such as repository, branch, pull request, commit, and issue links.

These records are bounded traceability records.
They do not transfer canonical ownership of source-control truth into Project V.

---

## Route Family

### `GET /api/projects/:projectId/github-links`
List GitHub links for one project.

### `GET /api/projects/:projectId/github-links/:githubLinkId`
Get one GitHub link.

### `POST /api/projects/:projectId/github-links`
Create a bounded GitHub link.

### `PATCH /api/projects/:projectId/github-links/:githubLinkId`
Update bounded mutable GitHub-link fields.

No generic delete route exists in the first pass.

---

## Scope Rules

- every route is project-scoped
- `githubLinkId` alone must not bypass project ownership rules
- source entity references must belong to the same project
- cross-project existence leakage is forbidden by default
- GitHub linkage records are planning-side traceability records, not source-control ownership records

---

## `GET /api/projects/:projectId/github-links`

### Query parameters
Allowed first-pass filters:

- `linkType`
- `sourceEntityType`
- `sourceEntityId`
- `limit`
- `cursor`

### Ordering
Default ordering should be deterministic:

```text
createdAt desc, id asc
```

### Response shape
Each item should expose at least:

- `id`
- `projectId`
- `sourceEntityType`
- `sourceEntityId`
- `linkType`
- `url`
- `externalId`
- `label`
- `createdAt`
- `updatedAt`

---

## `GET /api/projects/:projectId/github-links/:githubLinkId`

### Failure posture
- `404` if the GitHub link does not belong to the project or does not exist
- `400` for malformed identifiers

---

## `POST /api/projects/:projectId/github-links`

### Required input
- `sourceEntityType`
- `sourceEntityId`
- `linkType`
- `url`

### Optional input
- `externalId`
- `label`

### Validation
- `sourceEntityType` must be allowed by the governed polymorphic-reference rules
- source entity must belong to the same project
- `linkType` must use controlled vocabulary
- `url` must be non-empty and must begin with `https://`; a value that fails this check must fail with `400 Bad Request`
- existence of the referenced URL is not validated; Project V does not make outbound calls to GitHub (see External Reference Validation Rule in `docs/api/api-conventions.md`)
- staleness of the referenced URL is the caller's responsibility
- the API must not imply canonical ownership of the linked external source-control object
- duplicate logical linkage must fail deterministically with `409 Conflict`; a unique constraint on `(projectId, sourceEntityType, sourceEntityId, linkType, url)` is enforced without exception

### Response
- `201 Created` with canonical GitHub-link record

---

## `PATCH /api/projects/:projectId/github-links/:githubLinkId`

### Allowed mutable fields
- `url`
- `externalId`
- `label`

### Validation
- `url`, if supplied, must be non-empty and must begin with `https://`; a value that fails this check must fail with `400 Bad Request`

### Forbidden first-pass mutations
- changing `projectId`
- changing canonical `id`
- changing source entity identity
- changing `linkType`
- silently converting a bounded traceability record into claimed ownership of GitHub truth

### Response
- `200 OK` with updated canonical GitHub-link record

---

## Controlled Vocabularies

Allowed values are governed by:

- `docs/architecture/data/controlled-vocabularies.md`

Relevant vocabulary:

- GitHub link type

---

## Error Posture

First-pass expected error classes:

- `400 Bad Request` for malformed input
- `404 Not Found` for missing or out-of-scope project-scoped records
- `409 Conflict` for duplicate logical linkage (same `projectId`, `sourceEntityType`, `sourceEntityId`, `linkType`, and `url`)
- `422 Unprocessable Entity` for semantically invalid but well-formed linkage requests

Use the common Project V error body shape governed by:

- `docs/api/api-conventions.md`

---

## Hammer Expectations

This family should be hammered for:

- project-scope enforcement
- same-project source-entity enforcement
- deterministic listing
- invalid `linkType` rejection
- invalid or empty `url` rejection
- duplicate-link rejection where required
- bounded traceability posture rather than ownership blur

---

## Final Rule

GitHub linkage routes should exist only as bounded traceability surfaces.

If they start behaving like a shadow GitHub client or a source-control warehouse, the design is wrong.

