# ADR-0003: Governed Schema and Endpoint Expansion

## Status

Accepted.

---

## Context

Project V is intended to be strict, multi-project-safe, and resistant to architectural drift.

Uncontrolled schema growth and endpoint sprawl are two of the fastest ways to destroy that goal.

A system that adds fields, tables, and routes casually during implementation will eventually become:

- harder to classify
- harder to test
- harder to harden
- easier to drift
- more confusing for humans and LLMs

That is unacceptable.

---

## Decision

Project V adopts governed expansion for both schema and endpoints.

After the initial approved core model and endpoint families are established:

- later additions are exceptional, not routine
- each change requires written justification
- each change must be checked against ownership, scope, and multi-project safety
- each meaningful change must be hammered

Implementation convenience is not sufficient reason to expand the model or the API.

---

## Rules

### Schema changes

A schema change must justify:

- why the truth belongs in Project V
- why the shape is canonical rather than derived
- why existing schema is insufficient
- how scope and integrity are enforced
- what hammer coverage will verify it

### Endpoint changes

An endpoint change must justify:

- why existing route families are insufficient
- what bounded capability it exposes or mutates
- how project scope is resolved
- what validation posture it requires
- how deterministic behavior is preserved

### Freeze posture

The initial schema and endpoint families should be treated as the governed base.

Future additions must be reviewed, documented, and tested rather than casually appended during development.

---

## Why

This decision is adopted because it:

- reduces schema drift
- reduces API sprawl
- protects multi-project integrity
- improves testability
- improves LLM readability and safer generation
- lowers long-term maintenance cost

---

## Consequences

### Positive

- architecture stays easier to reason about
- docs remain closer to repo truth
- hammer planning stays aligned to actual contracts
- implementation work is forced to conform to governed structure

### Negative

- adding new fields or routes becomes slower
- more review discipline is required
- convenience shortcuts are intentionally rejected

These are acceptable costs.

---

## Companion Docs

- `docs/architecture/data/schema-governance.md`
- `docs/api/endpoint-governance.md`
- `docs/architecture/testing/hammer-doctrine.md`
- `docs/architecture/testing/hammer-plan.md`
