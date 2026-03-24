# Hammer Plan

## Purpose

This document turns the Project V hammer doctrine into an initial execution plan.

It exists to answer:

```text
What should the first hammer modules test, in what order, and which invariants do they protect?
```

---

## Core Rule

Project V should not claim to be hardened until its highest-risk invariants are covered by repeatable hammer modules.

Happy-path proof is not enough.
Each important area needs:

- valid-path coverage
- invalid-path coverage
- persistence inspection
- boundary-pressure coverage
- deterministic assertions

---

## Initial Hammer Phases

### Phase 1: Core persistence and scope

Goal:

- prove the basic multi-project data model is structurally safe

Modules:

- `hammer-core-projects`
- `hammer-core-objectives`
- `hammer-core-initiatives`
- `hammer-core-work-items`
- `hammer-scope-isolation`

Protects invariants:

- project-scoped rows belong to exactly one project
- orphaned canonical records are rejected
- list behavior is deterministic
- writes require valid scope
- cross-project leakage fails

### Phase 2: state, decisions, and rollback

Goal:

- prove that important state changes are explicit, aligned, and atomic

Modules:

- `hammer-state-transitions`
- `hammer-decisions`
- `hammer-transaction-rollback`

Protects invariants:

- illegal state jumps fail
- decision/history alignment holds
- partial writes do not survive failed mutations

### Phase 3: readiness and gaps

Goal:

- prove readiness is inspectable, reproducible, and not magic

Modules:

- `hammer-readiness-core`
- `hammer-readiness-gaps`
- `hammer-readiness-reproducibility`

Protects invariants:

- readiness requires visible basis
- gaps are recorded explicitly
- advisory outputs do not silently mutate canonical state
- same inputs produce same readiness result

### Phase 4: evidence, research, and honesty

Goal:

- prove supporting artifacts remain directional and honest

Modules:

- `hammer-research-docs`
- `hammer-evidence-links`
- `hammer-derived-honesty`

Protects invariants:

- evidence links do not overclaim ownership
- imported or derived artifacts remain non-canonical where appropriate
- summaries do not silently replace source planning truth

### Phase 4.5: polymorphic references, audits, and GitHub linkage

Goal:

- prove the BYDA / traceability extension stays same-project, bounded, deterministic, and honest

Modules:

- `hammer-polymorphic-references`
- `hammer-audits`
- `hammer-audit-readiness-coupling`
- `hammer-cross-artifact-consistency`
- `hammer-ambiguity-detection`
- `hammer-github-links`

Protects invariants:

- same-project polymorphic resolution holds
- cross-project audit and linkage targets fail safely
- required audit outcomes constrain readiness honestly
- cross-artifact contradictions are detected
- ambiguity detection behaves deterministically for governed patterns
- GitHub linkage remains bounded traceability rather than ownership blur
- audit gaps remain separate from readiness gaps

### Phase 5: handoffs and boundary enforcement

Goal:

- prove Project V does not collapse into VEDA or V Forge

Modules:

- `hammer-handoffs`
- `hammer-boundary-enforcement`
- `hammer-cross-system-references`

Protects invariants:

- handoffs require explicit target-system classification
- Project V does not accept observatory truth as its own canonical state
- Project V does not accept execution truth as its own canonical state
- cross-system references remain explicit and bounded

#### Integration Hammer Scenarios — Phase 5

These scenarios must be covered within Phase 5 modules.
Each addresses a concrete failure mode at an integration boundary.

**Stale external references**

- Scenario: A Project V record references a VEDA or V Forge identifier that no longer exists or is no longer valid in the source system.
- Required behavior: The system must not silently accept a stale reference as current truth. Stale identifiers must be detectable and flagged during audit or readiness evaluation. Planning records must not elevate a stale reference to canonical planning truth.
- Coverage target: `hammer-cross-system-references`

**Invalid external identifiers**

- Scenario: A handoff, evidence link, or cross-system reference is submitted with an external identifier that does not conform to the expected format or that is structurally invalid.
- Required behavior: The write is rejected at the contract level. The system does not store a malformed external reference and treat it as though it were valid.
- Coverage target: `hammer-cross-system-references`, `hammer-handoffs`

**Cross-project contamination via integration path**

- Scenario: A Project V record in project A references a VEDA observation or V Forge work package that belongs to project B.
- Required behavior: Cross-project external references are rejected or fail safely. Project scope must be preserved across integration boundaries. Project A must not silently acquire planning truth grounded in project B's external records.
- Coverage target: `hammer-scope-isolation`, `hammer-cross-system-references`

**Provenance violations**

- Scenario: A planning conclusion derived from a VEDA observation is stored in a way that loses or hides the original VEDA provenance.
- Required behavior: The system must not allow a derived planning interpretation to become detached from its VEDA source reference. Evidence links and decision records that cite VEDA material must preserve recoverable provenance.
- Coverage target: `hammer-evidence-links`, `hammer-cross-system-references`

**Observatory-shaped payload stored as canonical Project V state**

- Scenario: A payload that contains observatory-shaped truth (SERP data, crawl observations, GA4 signals) is submitted to a Project V write surface.
- Required behavior: The write is rejected. Project V canonical tables do not accept observatory-shaped payloads as owned state.
- Coverage target: `hammer-boundary-enforcement`

**Execution-shaped payload stored as canonical Project V state**

- Scenario: A payload that contains execution-state truth (draft state, revision workflow, publish status) is submitted to a Project V write surface.
- Required behavior: The write is rejected. Project V canonical tables do not accept execution-shaped payloads as owned state.
- Coverage target: `hammer-boundary-enforcement`

### Phase 6: contract hardening

Goal:

- prove routes behave exactly and fail exactly

Modules:

- `hammer-contracts-read`
- `hammer-contracts-write`
- `hammer-ordering`
- `hammer-validation`

Protects invariants:

- response shape is stable
- validation is deterministic
- ordering is deterministic
- negative paths fail correctly

### Phase 7: coordinator regression

Goal:

- prove the whole hammer suite can be rerun as a reliable gate

Modules:

- `hammer-coordinator`

Protects invariants:

- broad regression coverage remains repeatable
- one broken area does not hide behind local passing tests

---

## Concurrency Probes

Concurrency scenarios must be included in the hammer suite.
They are not optional.

Required scenarios are defined in `docs/architecture/testing/hammer-doctrine.md` under
"Concurrency and Race-Condition Coverage".

Summary of required concurrency probes for this plan:

- concurrent conflicting status transitions — `hammer-state-transitions`
- duplicate dependency creation race — `hammer-dependencies`
- duplicate readiness evaluation trigger — `hammer-readiness-core`
- concurrent project-scoped unique key creation — `hammer-core-projects`, `hammer-core-work-items`

These scenarios should be scheduled inside the phases where the relevant modules appear.
First-pass concurrency testing uses sequential requests inside a single run; no distributed
simulation is required.

---

## Initial High-Risk Probes

The earliest hammer suite should intentionally try to break Project V through cases like:

- create project-scoped records without a project
- create records under the wrong project context
- read a row from another project by direct identifier
- create cross-project dependencies without explicit support
- record readiness with no inspectable basis
- create history without the corresponding state change
- change state without required history
- allow non-deterministic list ordering
- persist derived convenience data as if it were canonical truth
- create handoffs without valid target-system classification
- treat stale audit confidence as if it were current
- let a required audit fail without constraining readiness
- miss a material contradiction between schema, API, or transition docs

---

## Suggested Module Naming Rule

Use:

```text
hammer-<bounded-concern>
```

Examples:

- `hammer-scope-isolation`
- `hammer-readiness-core`
- `hammer-transaction-rollback`
- `hammer-boundary-enforcement`

Keep names explicit and tied to the invariant being stressed.

---

## Coverage Mapping Rule

Each hammer module should identify:

- the invariant(s) it covers
- the records or routes it touches
- the setup required
- the valid path being verified
- the invalid path being verified
- the exact pass criteria

If a module cannot explain what it is protecting, it is too vague.

The explicit invariant-to-module coverage map lives in:

- `docs/architecture/testing/hammer-coverage-map.md`

That map must be updated whenever a new hammer module is added or an existing module is retired.
A module that does not appear in the coverage map is not counted as coverage.

---

## Coordinator Rule

A full coordinator should eventually run all active hammer modules in a stable order.

The coordinator should produce a result that is easy to classify, such as:

- pass count
- fail count
- skip count
- failing module names

The coordinator should become part of the standard hardening gate before major schema or endpoint expansion.

---

## Final Rule

Do not call Project V hardened because it works in the happy path once.

Call it hardened when the hammer can repeatedly prove:

- scope safety
- transaction safety
- readiness honesty
- boundary integrity
- deterministic behavior
- correct failure under pressure
