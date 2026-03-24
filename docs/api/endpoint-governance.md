# Endpoint Governance

## Purpose

This document defines the rules for Project V endpoint design and endpoint change.

It exists to answer:

```text
How do we keep Project V API surfaces strict, multi-project-safe, and protected from endpoint sprawl during development?
```

---

## Core Judgment

Project V should not accumulate endpoints casually.

Endpoints are part of the bounded system contract.
They should be designed from the governed domain model, not improvised one request at a time until the API turns into a patchwork of convenience routes.

Once the initial endpoint families are approved, further additions should be rare, justified, documented, and hammered.

---

## Primary Rule

No new endpoint is allowed merely because it feels convenient for the current surface.

A new endpoint must justify:

- why the capability belongs in Project V
- why existing endpoint families are insufficient
- what bounded system truth it exposes or mutates
- how project scope is resolved and enforced
- what invariant or operator workflow requires it

If that justification is weak, the endpoint should not be added.

---

## Endpoint Design Principles

### 1. Endpoints must expose bounded Project V truth

Project V endpoints should expose planning and orchestration truth.

They must not masquerade as VEDA observability endpoints or V Forge execution endpoints.

### 2. Prefer endpoint families over one-off route scatter

Design endpoints as coherent families.

Examples:

- projects
- objectives
- initiatives
- work-items
- readiness
- decisions
- handoffs

Do not create isolated convenience routes that do not belong to a clear family.

### 3. Read and write concerns should remain explicit

Read routes and mutation routes should be clearly distinguishable.

Mutation endpoints should be especially strict about validation, scope, and state transition rules.

### 4. Project scope must be visible in the contract

At 100+ projects, endpoint scope cannot rely on operator memory or hidden defaults.

A route must make it clear:

- whether it is project-scoped
- how project context is supplied
- whether cross-project access is allowed
- how unauthorized or cross-project access fails

### 5. Deterministic outputs are required

List and queue-style endpoints must define deterministic ordering.
No route may rely on implicit ordering.

---

## Endpoint Change Gate

A new endpoint or endpoint shape change should only be allowed when all of the following exist:

1. **clear bounded purpose**
2. **written contract intent**
3. **project scope behavior defined**
4. **validation behavior defined**
5. **deterministic ordering defined where relevant**
6. **hammer coverage or hammer updates**
7. **existing route reuse considered**

If one of these is missing, the endpoint is not ready.

---

## Required Questions For Every Endpoint

### Ownership

- Is this exposing Project V truth rather than VEDA or V Forge truth?
- Is this route family consistent with Project V bounded ownership?

### Scope

- Is the route project-scoped or intentionally broader?
- How is project context resolved?
- How are cross-project reads and writes prevented?

### Mutation discipline

- Is this route read-only or mutating?
- If mutating, what explicit action is being requested?
- What state transitions are allowed or forbidden?

### Validation

- What input is required?
- What failures are blocking vs advisory?
- What exact error posture should callers expect?

### Output

- What response shape is canonical?
- Is the output deterministic?
- Are derived fields clearly derived?

If the answers are vague, the endpoint is not ready.

---

## Anti-Sprawl Rules

### 1. No route-per-screen thinking

Do not create endpoints just because a specific UI or tool wants a one-off shape.

Prefer reusable, bounded route families.

### 2. No hidden convenience mutations

A route that sounds read-only must not mutate state behind the scenes.

### 3. No duplicate route families for the same concept

Do not create multiple overlapping ways to read or mutate the same canonical truth unless the distinction is explicit and necessary.

### 4. No ambiguous multi-purpose endpoints

A single endpoint should not attempt to handle unrelated behaviors based on vague flags.

### 5. No silent project inference for writes

Mutation endpoints must require explicit project context where project-scoped truth is involved.

---

## Recommended First-Pass Endpoint Families

The initial Project V endpoint surface should stay close to the initial domain model. The following families are active in the first pass and have governing API contract docs:

- project context and project listing (`projects-api.md`)
- objectives (`objectives-api.md`)
- initiatives (`initiatives-api.md`)
- work-items (`work-items-api.md`)
- dependencies (`dependencies-api.md`)
- decision records (`decision-records-api.md`)
- readiness evaluations and gaps (`readiness-api.md`)
- research docs (`research-docs-api.md`)
- evidence links (`evidence-links-api.md`)
- handoffs (`handoffs-api.md`)
- github links (`github-links-api.md`)

These families should be hardened before adding further surface area.

### Explicitly deferred endpoint families

The following have API doc files in the repo but are **not active first-pass surfaces**. These are documented gaps or reserved design docs, not oversights.

**AuditRun / AuditGap** (`audits-api.md`)
Full schema is defined. No API surface in the first pass. Audit execution happens through internal server-side logic only. A governed audit endpoint family should be designed and added in a later pass before audit functionality is exposed to callers. See `docs/api/audits-api.md` for the deferred design.

**StatusHistory** (`status-history-api.md`)
StatusHistory records are written atomically with governed status transitions. There is no first-pass read surface. Status history is write-only from the API perspective. If transition audit trail inspection is required, a read surface must be added through governance. See `docs/api/status-history-api.md` for the deferred design.

**ArtifactManifests** (`artifact-manifests-api.md`)
No schema exists for this table in the first-pass canonical table set. The API doc reserves and governs the future surface direction only. This family must not be treated as active until the underlying model is explicit, governed, and hammered.

---

## Contract Posture

Project V contracts should be:

- explicit
- deterministic
- boring
- stable
- easy for both humans and LLMs to reason about

Good contract design reduces prompt ambiguity, operator mistakes, and route drift.

---

## Hammer Expectations

Important endpoints should be hammered for:

- project-scope enforcement
- validation behavior
- deterministic ordering
- transaction correctness where relevant
- negative-path rejection
- boundary honesty

See:

- `docs/architecture/testing/hammer-doctrine.md`
- `docs/architecture/testing/hammer-plan.md`

---

## Final Rule

Treat Project V endpoints as governed contracts.

If a route would make the API:

- broader without clearer ownership
- more ambiguous
- less multi-project-safe
- harder to test
- easier to sprawl

then the route is wrong.
