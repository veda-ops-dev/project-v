# Hammer Doctrine

## Purpose

This document defines the hammer-testing doctrine for Project V.

It exists to answer:

```text
How should Project V be tested so the database, contracts, and orchestration rules are hardened instead of merely assumed?
```

Project V should adopt the same broad posture that proved valuable in VEDA:

- test real behavior
- test invariants directly
- probe for breakage intentionally
- treat passing happy paths as insufficient

---

## Core Rule

Hammer tests exist to verify that Project V preserves its system invariants under realistic execution and deliberate boundary pressure.

Their job is not to perform shallow demo validation.
Their job is to make it hard for architectural drift, weak contracts, partial writes, or convenience shortcuts to survive unnoticed.

---

## What the Hammer Is

The hammer is a testing doctrine centered on:

- invariant-first validation
- real database interaction
- real contract execution
- deliberate misuse probes
- deterministic assertions
- regression resistance

The hammer should prove not only that Project V works when used correctly, but also that it fails correctly when used incorrectly.

---

## What the Hammer Is Not

The hammer is not:

- UI screenshot theater
- mock-heavy false confidence
- shallow endpoint smoke testing only
- a substitute for unit tests
- a substitute for architecture discipline

Unit tests still matter.
Type safety still matters.
Linting still matters.
But hammer tests are where the system proves its bounded behavior under realistic persistence and contract conditions.

---

## Primary Goals

Project V hammer tests should protect:

- bounded ownership integrity
- database integrity
- transaction integrity
- readiness and gating integrity
- deterministic ordering
- traceability integrity
- explicit-state-transition discipline
- cross-system boundary integrity

---

## Doctrine

### 1. Invariants first

Every meaningful hammer module should correspond to one or more Project V invariants.

If a behavior matters architecturally, there should be a hammer path that can prove it or break it.

### 2. Real execution over mock theater

Where practical, hammer tests should exercise:

- real route handlers
- real validation
- real database writes and reads
- real transaction behavior

The closer the hammer is to real execution, the more trustworthy it is.

### 3. Exact contract beats vibes

A route should not merely return something plausible.
It should return the correct status, the correct shape, the correct error posture, and the correct state behavior.

### 4. Breakage attempts are required

Each important surface should be tested in at least two ways:

- valid use
- invalid or hostile use

Project V should be probed for:

- missing required data
- invalid transitions
- illegal cross-system references
- non-deterministic ordering
- partial write exposure
- readiness claims without evidence

### 5. Boring structure wins

Hammer modules should be easy to read, easy to rerun, and easy to classify.

A future operator or LLM should be able to tell:

- what invariant is being tested
- what setup is required
- what pass looks like
- what fail means

---

## Hammer Categories

### 1. Persistence hammer

These tests verify database truth and integrity.

Examples:

- required records persist correctly
- invalid writes are rejected
- foreign-key-like ownership assumptions are enforced
- multi-write mutations roll back correctly on failure

### 2. Contract hammer

These tests verify route and API contract behavior.

Examples:

- response status and shape
- validation errors
- deterministic ordering
- explicit missing-resource behavior

### 3. Mutation-boundary hammer

These tests verify that state changes obey bounded rules.

Examples:

- illegal state transition attempts fail
- explicit actions are required for readiness changes
- derived outputs do not silently overwrite canonical planning truth

### 4. Readiness hammer

These tests verify that gating and audit behavior are explainable and inspectable.

Examples:

- a readiness evaluation records its basis
- readiness gaps appear when conditions fail
- the same evaluation yields the same result on the same inputs
- advisory outputs do not silently mutate canonical records

### 5. Boundary hammer

These tests verify that Project V does not collapse into VEDA or V Forge responsibilities.

Examples:

- observatory-shaped payloads cannot be stored as canonical Project V truth
- execution-only state cannot be smuggled into Project V models
- cross-system writes through convenience paths are rejected

### 6. Determinism hammer

These tests verify that stable inputs produce stable outputs.

Examples:

- list ordering remains deterministic
- queue selection remains deterministic
- readiness evaluation remains reproducible
- context assembly does not reorder arbitrarily

---

## Initial Hammer Targets

The first Project V hammer packages should target the highest-risk invariants first.

### Phase 1

- database bootstrap and schema validity
- core project / objective / initiative / work-item persistence
- deterministic list ordering
- basic validation failure cases

### Phase 2

- readiness evaluation creation and gap recording
- explicit state-transition rules
- decision-record alignment with important state changes
- transaction rollback behavior for multi-write mutations

### Phase 3

- evidence-link integrity
- handoff boundary enforcement
- imported/derived record honesty
- cross-system reference validation

### Phase 4

- broader orchestration flows
- queue/selection determinism
- MCP-facing contract hardening
- regression coordinator that runs the whole hammer suite

---

## Test Design Rules

### 1. Name modules by bounded concern

Examples:

- `hammer-core`
- `hammer-readiness`
- `hammer-dependencies`
- `hammer-handoffs`
- `hammer-contracts`

### 2. Keep fixtures explicit

Test setup should make ownership and intent visible.
Do not hide important state assumptions in mystery helpers.

### 3. Prefer exact assertions

Assert exact failure reasons, exact ordering, exact mutation effects, and exact rollback behavior where practical.

### 4. Probe rollback deliberately

If an operation claims atomicity, the hammer should attempt to break the operation mid-flight and verify rollback.

### 5. Test the negative path on purpose

If a behavior should fail, that failure should be part of the expected passing test result.

---

## Initial Failure Modes to Probe

Project V hammer tests should try to break the system through cases like:

- creating readiness results without evaluable basis
- recording handoffs without valid target-system classification
- allowing illegal state jumps
- persisting orphaned dependent records
- emitting history without corresponding state change
- changing state without corresponding required history
- returning non-deterministic ordering for identical data
- accepting over-broad external references as canonical truth
- silently mutating canonical planning records via derived outputs

---

## Relationship to Invariants

The hammer suite should be mapped directly to:

- `docs/architecture/core/system-invariants.md`
- `docs/architecture/data/db-boundaries.md`

If a new invariant is added, the hammer plan should be reviewed.
If a critical invariant has no hammer coverage, that is a gap.

The explicit invariant-to-module mapping lives in:

- `docs/architecture/testing/hammer-coverage-map.md`

That map must be kept synchronized with this doctrine and the hammer plan.
An invariant that does not appear in the coverage map is not protected.

---

## Success Standard

A Project V surface is not considered hardened because it appears to work once.

A surface is hardened when:

- its invariant obligations are explicit
- its valid behavior is verified
- its invalid behavior is rejected correctly
- its persistence effects are inspectable
- its rollback posture is verified where relevant
- its results are repeatable

---

## Maintenance Rule

When a new important Project V capability is added:

1. identify the invariants it touches
2. add or extend hammer coverage
3. verify both valid and invalid paths
4. rerun the broader coordinator suite

Do not call a capability complete until it survives the hammer.

---

## Hammer Enforcement Gate

Hammer is not advisory. It is a hard gate.

Hammer must pass before:

- **schema changes** — any addition, removal, or modification to the Project V schema
- **API changes** — any new endpoint family, new route, or change to an existing contract
- **readiness or audit logic changes** — any modification to how readiness is evaluated, how gaps are recorded, or how audit results constrain planning state

This gate is a policy requirement, not a CI rule.
It applies regardless of whether automated tooling enforces it.

If hammer cannot pass after a proposed change, the change is not ready.
If hammer coverage does not exist for the area being changed, adding that coverage is part of the work, not an afterthought.

The gate applies to both valid-path and invalid-path coverage.
A change that adds a capability but only adds happy-path hammer coverage has not cleared the gate.

---

## Concurrency and Race-Condition Coverage

Hammer tests must include concurrency scenarios for high-risk areas.

Single-thread logic passing is not sufficient proof that a surface is hardened.
Real conditions include simultaneous writes, competing transitions, and duplicate creation races.

Required concurrency scenarios:

### Concurrent status transitions

- Attempt to transition a work item, initiative, or other status-bearing record through two conflicting states simultaneously.
- Expected result: exactly one transition succeeds; the other fails with a clear rejection. No silent corruption. No ambiguous final state.
- Coverage module: `hammer-state-transitions`

### Duplicate dependency creation

- Attempt to create the same dependency relationship from two concurrent requests.
- Expected result: exactly one creation succeeds; the other fails with a conflict error. No orphaned or duplicate dependency row.
- Coverage module: `hammer-dependencies` (when scoped; add if not present)

### Readiness evaluation races

- Attempt to trigger a readiness evaluation on the same target from two concurrent requests.
- Expected result: the system does not produce duplicate evaluation records for the same evaluation run. Concurrent reads of evaluation state remain consistent.
- Coverage module: `hammer-readiness-core`

### Concurrent canonical record creation

- Attempt to create two records with the same project-scoped unique key simultaneously.
- Expected result: exactly one creation succeeds; the other is rejected with a uniqueness violation. No silent duplicate.
- Applicable to any record with a `projectId + key` uniqueness constraint.
- Coverage module: `hammer-core-projects`, `hammer-core-work-items` (and equivalent per record type)

First-pass concurrency testing does not require distributed simulation.
Two sequential requests inside a single hammer run, designed to stress the same constraint, are sufficient for first pass.
The goal is to verify that the uniqueness and transaction posture holds under pressure, not to simulate production load.

---

## Test Environment and Isolation Posture

Hammer tests use a real database. That means test environment posture must be explicit.

### Reset strategy

Each hammer module run should start from a known, clean state.

Preferred approach for first pass:

- truncate relevant tables before each module run, or
- use transaction-wrapped test cases that roll back after each case

Choose one strategy and apply it consistently within a module.
Do not allow one hammer module's fixture data to bleed into another module's assertions.

### Isolation expectations

- Hammer modules must not depend on data created by a previous module run.
- Hammer modules must not depend on implicit global state from the application or environment.
- Fixtures must be created explicitly within the module or its setup step.
- Module ordering in the coordinator must not be required to produce a correct per-module result.

If a module requires setup from another module to pass, that is a design flaw in the module, not an acceptable dependency.

### Reproducibility requirements

- Running the same hammer module twice against the same clean state must produce the same result.
- A module that passes on first run but fails on second run without any code change is flaky and must be treated as a defect.
- Non-deterministic ordering, time-dependent assertions, or hidden global state are not acceptable in hammer modules.

### Environment definition

- Hammer tests run against the `project_v` database on the shared local Postgres cluster.
- The database must exist and migrations must have run before the hammer suite starts.
- Hammer should not attempt to run its own migrations. Schema is the responsibility of the governed migration path.
- Connection configuration should come from the same source as the application, not from hardcoded hammer-only config.

This posture is first-pass and implementation-neutral.
It does not require a test framework, ORM, or runner to be chosen.
The rules apply regardless of implementation choice.
