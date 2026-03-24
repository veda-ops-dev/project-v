# ADR-0004: Separate Audit and Readiness Records

## Status

Accepted.

---

## Context

Project V already defines first-pass readiness records:

- `ReadinessEvaluation`
- `ReadinessGap`

The BYDA extension layer introduces additional concepts:

- `AuditRun`
- `AuditGap`
- `GitHubLink`

A structural decision is required:

- expand readiness records until they absorb BYDA-style audit
- or model audit as a separate but related subsystem

If this decision is left unresolved, implementation will invent its own boundary between readiness and audit.

That is unacceptable.

---

## Decision

Project V will model **audit records separately from readiness records**.

First-pass direction:

- `ReadinessEvaluation` and `ReadinessGap` remain the canonical readiness-gate records
- `AuditRun` and `AuditGap` become separate records for BYDA-style audit and lifecycle-governance outcomes
- `GitHubLink` becomes the bounded implementation-traceability linkage record for GitHub-related references

Readiness and audit remain related, but they are not collapsed into one generic table family.

---

## Why

This decision is adopted because:

- readiness answers whether something may move forward
- audit answers what was checked, how it was checked, and what governance failures or gaps were found
- BYDA-style audit needs richer lifecycle and artifact-aware framing than the first-pass readiness records currently provide
- forcing audit into readiness would blur two different kinds of truth

---

## Consequences

### Positive

- readiness stays smaller and clearer
- BYDA-style audit can evolve without distorting readiness records
- lifecycle invalidation and richer audit outputs become easier to model
- code-alignment and artifact-aware audit can be added without overloading readiness

### Negative

- more tables are required
- linking readiness and audit must be explicit rather than assumed
- audit APIs and schema must be governed separately

These are acceptable tradeoffs.

---

## First-Pass Schema Decision

Project V should treat these as first-pass schema additions before implementation begins in earnest:

- `AuditRun`
- `AuditGap`
- `GitHubLink`

The following remain deferred unless explicitly promoted later:

- `ArtifactManifest`
- `ArtifactDeclaration`
- `ImplementationPackage`
- `DriftFinding`
- dedicated `AuditLayerResult`

---

## Companion Rules

- readiness remains server-owned and governed by readiness rules
- audit remains artifact-aware and lifecycle-aware
- any coupling between audit and readiness must be explicit
- GitHub linkage remains bounded traceability, not source-control ownership

---

## Companion Docs

- `docs/architecture/core/byda-in-project-v.md`
- `docs/architecture/data/audit-and-gap-model.md`
- `docs/architecture/data/github-linkage-model.md`
- `docs/architecture/data/schema-authority.md`
- `docs/architecture/data/schema-specification.md`
