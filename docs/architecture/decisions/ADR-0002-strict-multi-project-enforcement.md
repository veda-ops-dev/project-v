# ADR-0002: Strict Multi-Project Enforcement

## Status

Accepted.

---

## Context

Project V is being built for 100+ projects, not a small single-project environment.

At that scale, operator memory, hidden defaults, and loose conventions are not sufficient.

If project scope is not enforced structurally, the system will drift toward:

- cross-project leakage
- ambiguous reads
- accidental writes under the wrong project
- weak uniqueness rules
- hard-to-debug orchestration errors

That is unacceptable.

---

## Decision

Project V is multi-project by structure, not by convention.

Every record must be classified as one of the following:

- project-scoped
- intentionally global
- system metadata

Project-scoped records must belong to exactly one project.
Global records must be rare and justified.
System metadata must not become a hidden loophole for project-owned truth.

Reads and writes must enforce explicit project scope.

---

## Rules

### Project-scoped rows

Project-scoped records must:

- belong to exactly one project
- be unreadable across project boundaries by default
- require explicit project context for writes
- reject illegal cross-project relations

### Global rows

Global rows must:

- be rare
- be documented
- have a clearly justified reason to be global

### Reads

Reads must:

- resolve project scope explicitly where required
- avoid cross-project existence leakage by default
- return deterministic ordering

### Writes

Writes must:

- require explicit project context for project-scoped truth
- reject cross-project contamination
- preserve transactional integrity

---

## Why

This decision is adopted because it:

- protects correctness at scale
- makes LLM-assisted usage safer
- keeps operator surfaces honest
- reduces future cleanup cost
- forces schema and endpoint design to reflect real ownership

---

## Consequences

### Positive

- scope becomes queryable and enforceable
- debugging becomes more realistic at 100+ projects
- test coverage can probe real isolation rules
- route behavior becomes less ambiguous

### Negative

- hidden convenience defaults are disallowed
- more explicit context is required in APIs and tools
- schema design must be stricter from the start

These are acceptable costs.

---

## Companion Docs

- `docs/architecture/core/multi-project-doctrine.md`
- `docs/architecture/core/system-invariants.md`
- `docs/architecture/data/schema-governance.md`
- `docs/api/endpoint-governance.md`
