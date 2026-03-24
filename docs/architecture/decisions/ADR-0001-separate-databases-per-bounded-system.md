# ADR-0001: Separate Databases Per Bounded System

## Status

Accepted.

---

## Context

The V Ecosystem is intentionally divided into bounded systems:

- Project V = planning and orchestration
- VEDA = observability and intelligence
- V Forge = execution and production

These systems own different kinds of truth.

Project V owns planning and orchestration truth.
VEDA owns observatory truth.
V Forge owns execution and production truth.

A shared database across bounded systems would make it easier for implementation convenience, LLM-generated code, and operator shortcuts to blur canonical ownership.

That blur is unacceptable.

---

## Decision

Use one shared Postgres cluster with one database per bounded system.

Initial shape:

- `project_v`
- `veda`
- `v_forge`

Project V owns canonical persistence in `project_v`.
VEDA owns canonical persistence in `veda`.
V Forge owns canonical persistence in `v_forge`.

---

## Why

This decision is adopted because it:

- preserves bounded ownership
- improves LLM readability and safer code generation
- reduces convenience-driven domain collapse
- allows independent schema evolution later
- keeps infrastructure simple enough for local and early operational use

---

## Consequences

### Positive

- system truth stays easier to classify
- migrations stay system-owned
- credentials can be separated per system
- later infrastructure separation is easier
- cross-system boundaries stay visible

### Negative

- direct cross-system joins are discouraged
- explicit coordination patterns are required
- some convenience shortcuts become unavailable by design

These are acceptable tradeoffs.

---

## Rules Implied By This Decision

- no mixed canonical ownership across databases
- no direct convenience writes into another system's canonical tables
- cross-system references must remain explicit
- imported or derived convenience data must be marked as non-canonical where appropriate

---

## Companion Docs

- `docs/architecture/data/db-boundaries.md`
- `docs/architecture/core/project-v.md`
- `docs/architecture/core/system-invariants.md`
