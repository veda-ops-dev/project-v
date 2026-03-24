# Artifact Manifests API

## Status

**DEFERRED — not part of the first-pass active API surface.**

This document reserves and governs the future surface direction for the Project V `artifact-manifests` endpoint family.

It must not be treated as an active API contract. No schema exists for this table in the first-pass canonical table set. This family must not be implemented until the underlying model is explicit, governed, and hammered.

See:
- `docs/api/endpoint-governance.md` — Explicitly Deferred Endpoint Families

---

## Purpose

This document defines the future Project V `artifact-manifests` endpoint family direction.

It exists to answer:

```text
How should Project V expose declared artifact manifests for planning, audit, and drift visibility once the artifact model is adopted?
```

---

## Family Scope

This family is intended for project-scoped artifact manifest and artifact declaration records.

This doc exists to reserve and govern the future surface direction.
It does not claim that the supporting schema is already finalized.

---

## First-Pass Surface Direction

Likely route family:

- `GET /api/projects/:projectId/artifact-manifests`
- `GET /api/projects/:projectId/artifact-manifests/:artifactManifestId`
- `POST /api/projects/:projectId/artifact-manifests`
- `PATCH /api/projects/:projectId/artifact-manifests/:artifactManifestId`

---

## Governing Rule

If adopted, this family must preserve:

- project scope
- explicit artifact typing
- deterministic listing
- same-project ownership for declared targets
- compatibility with BYDA-style audit expectations

---

## Final Rule

Artifact manifests should only become a route family once the underlying model is explicit enough to govern.
