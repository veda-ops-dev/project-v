# Evidence Links API

## Purpose

This document defines the Project V `evidence-links` endpoint family.

It exists to answer:

```text
How are project-scoped evidence links listed, retrieved, created, and updated without overclaiming ownership of external truth?
```

Read this with:

- `docs/api/api-conventions.md`
- `docs/api/endpoint-governance.md`
- `docs/architecture/integrations/veda-integration.md`
- `docs/architecture/data/schema-authority.md`
- `docs/architecture/data/schema-specification.md`

---

## Family Scope

This family manages project-scoped EvidenceLink records.

Evidence links are directional planning-support records.
They do not turn referenced external material into Project V canonical truth.

---

## Route Family

### `GET /api/projects/:projectId/evidence-links`
List evidence links for one project.

### `GET /api/projects/:projectId/evidence-links/:evidenceLinkId`
Get one evidence link.

### `POST /api/projects/:projectId/evidence-links`
Create an evidence link.

### `PATCH /api/projects/:projectId/evidence-links/:evidenceLinkId`
Update bounded mutable evidence-link fields.

No delete route exists in the first pass.

---

## Scope Rules

- every route is project-scoped
- `evidenceLinkId` alone must not bypass project ownership rules
- source planning entities must belong to the same project
- cross-project existence leakage is forbidden by default
- external references remain external even when linked inside Project V

---

## `GET /api/projects/:projectId/evidence-links`

### Query parameters
Allowed first-pass filters:

- `sourceEntityType`
- `sourceEntityId`
- `evidenceType`
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
- `evidenceType`
- `targetLocator`
- `note`
- `relevanceScore`
- `createdAt`
- `updatedAt`

---

## `GET /api/projects/:projectId/evidence-links/:evidenceLinkId`

### Failure posture
- `404` if the evidence link does not belong to the project or does not exist
- `400` for malformed identifiers

---

## `POST /api/projects/:projectId/evidence-links`

### Required input
- `sourceEntityType`
- `sourceEntityId`
- `evidenceType`
- `targetLocator`

### Optional input
- `note`
- `relevanceScore`

### Validation
- `sourceEntityType` must use controlled vocabulary; allowed values: `objective`, `initiative`, `work_item`, `handoff`, `decision_record`, `research_doc`
- source entity must exist in the same project; polymorphic references must be resolved using the central resolver defined in `docs/architecture/data/polymorphic-reference-enforcement.md`
- `evidenceType` must use controlled vocabulary; allowed values: `document`, `observation`, `decision_basis`, `external_reference`; an unknown value must fail with `422 Unprocessable Entity`
- `targetLocator` must be non-empty; no URL format is enforced because evidence locators may reference non-URL paths or identifiers
- existence of the referenced target is not validated; Project V does not make outbound calls to resolve evidence targets (see External Reference Validation Rule in `docs/api/api-conventions.md`)
- staleness of the referenced target is the caller's responsibility
- `relevanceScore`, if present, must remain in the governed numeric range `0..100`; a value outside this range must fail with `422 Unprocessable Entity`
- the API must not imply canonical ownership of the referenced target

### Response
- `201 Created` with canonical evidence-link record

---

## `PATCH /api/projects/:projectId/evidence-links/:evidenceLinkId`

### Allowed mutable fields
- `note`
- `relevanceScore`

### Forbidden first-pass mutations
- changing `projectId`
- changing canonical `id`
- changing source entity identity
- silently reclassifying the external target into canonical Project V truth

### Response
- `200 OK` with updated canonical evidence-link record

---

## Error Posture

First-pass expected error classes:

- `400 Bad Request` for malformed input, missing required fields, or unknown body fields
- `404 Not Found` for missing or out-of-scope project-scoped records
- `422 Unprocessable Entity` for controlled-vocabulary violations, out-of-range relevance scores, or same-project integrity failures

Use the common Project V error body shape governed by `docs/api/api-conventions.md`.

---

## Hammer Expectations

This family should be hammered for:

- same-project source-entity enforcement
- invalid sourceEntityType rejection
- invalid evidenceType rejection
- deterministic listing
- invalid target-locator rejection
- provenance and ownership honesty
- invalid relevance-score rejection

---

## Final Rule

The Evidence Links API must preserve directional support relationships honestly.
A linked source is not the same thing as owned truth.


