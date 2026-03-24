# BYDA in Project V

## Purpose

This document defines how the BYDA methodology fits inside Project V.

It exists to answer:

```text
What does Project V keep from BYDA, what does it own, what does it not own, and how does BYDA shape planning, readiness, audit, and implementation governance?
```

---

## Core Rule

In Project V, BYDA is a governed planning, audit, readiness, and drift-control subsystem.
It should behave like a structured questioning layer tied to explicit audit types, lifecycle phases, and implementation consequences.

It is not a generic ritual.
It is not a replacement for implementation truth.
It is not a substitute for VEDA observatory truth or V Forge execution truth.

BYDA belongs in Project V because it governs:

- planning readiness
- audit gating
- cross-artifact consistency
- implementation traceability from the planning side
- drift detection from the planning side

---

## What Project V Should Keep From BYDA

Project V should keep these core BYDA ideas:

- explicit audit types tied to project lifecycle phases
- audit runs as first-class governed records
- gaps as first-class governed records
- artifact-aware evaluation rather than one-size-fits-all app assumptions
- cross-artifact contract consistency checks
- research-to-plan-to-implementation traceability
- rollback or major reversal invalidating stale downstream audit confidence

---

## What Project V Should Not Copy Blindly

Project V should not:

- cargo-cult old Project Planner table names
- force every project into a database/API-only audit model
- make GitHub the source of planning truth
- make BYDA an everything-system that swallows execution ownership

Project V should carry forward the strong ideas, not the legacy shape unchanged.

---

## Bounded Ownership

### Project V owns

Project V owns BYDA-related planning-side truth such as:

- audit definitions and audit type framing
- audit runs
- audit gaps
- planning-side readiness judgments
- artifact manifests used for planning and audit classification when later promoted
- planning-side implementation traceability
- planning-side drift visibility

### Project V does not own

Project V does not own:

- raw observatory truth from VEDA
- execution truth from V Forge
- GitHub itself as canonical source-control truth
- produced assets or publishing workflow truth

Project V may reference those systems and interpret their signals for audit and planning purposes.
It does not replace them.

---

## BYDA Questioning Principle

BYDA should be understood as a governed set of questions the system asks about a project, target record, or lifecycle transition.

Those questions should not be improvised ad hoc.
They should be tied to:

- audit type
- lifecycle phase
- target entity type
- governed artifacts or expected evidence
- readiness and implementation consequences

A useful first-pass shorthand is:

- `research` asks whether the project is clear enough to plan honestly
- `planning` asks whether the planning structure and governed docs agree enough to proceed
- `implementation_readiness` asks whether the work is ready to move toward implementation safely
- `code_alignment` asks whether governed intent and linked code evidence still match
- `handoff` asks whether the transition to another boundary is truly ready and explicit
- `hygiene` asks whether ambiguity, contradiction, or stale governance debt is accumulating

---

## BYDA Inside the Project V Lifecycle

BYDA should appear in Project V at multiple points:

### 1. Research and planning phase

BYDA helps test whether the project has enough structure, evidence, and bounded clarity to proceed.

### 2. Pre-implementation phase

BYDA should act as a readiness and audit gate before implementation preparation or implementation tracking moves forward.

### 3. Implementation phase

BYDA should support code-traceability and spec-to-code drift visibility from the planning side.

### 4. Handoff / launch / closure phases

BYDA should support bounded audit results appropriate to the lifecycle stage.

---

## Audit Types in Project V

Project V should support multiple audit types rather than treating every audit as the same thing.

A practical first-pass framing is:

- research audit
- planning audit
- implementation-readiness audit
- code-alignment audit
- handoff audit
- hygiene audit

The exact names may evolve, but the architecture should preserve the idea that audit purpose changes by lifecycle phase.

---

## Artifact-Aware Audit Principle

Project V should not assume every project has the same artifact set.

BYDA in Project V should evaluate projects based on declared artifacts or governed expectations such as:

- schema or migration artifacts
- API contract artifacts
- validation artifacts
- infrastructure artifacts
- config artifacts
- workflow docs
- code linkage artifacts
- test artifacts

This is important because Project V is multi-project and the ecosystem will not always produce identical project shapes.

---

## Cross-Artifact Consistency Principle

One of the most valuable BYDA ideas is cross-artifact consistency checking.

Project V should preserve that idea explicitly.

Examples:

- schema docs and API contracts should not disagree
- status-transition docs and explicit status routes should not disagree
- artifact expectations and audit conclusions should not disagree
- implementation linkage and governed implementation intent should not disagree

This belongs in Project V because it is planning and governance truth.

---

## BYDA Outputs

A first-pass BYDA audit should produce explicit, inspectable outputs such as:

- audit type
- target entity
- result
- summary
- generated gaps where needed
- staleness or invalidation state where applicable

Those outputs should be strong enough to affect readiness and workflow honestly.

---

## Relationship to Readiness

BYDA does not replace readiness.
BYDA strengthens readiness.

Readiness answers:

- can this move forward?

BYDA answers additional questions like:

- what was audited?
- what failed?
- what gaps exist?
- how strong is the evidence that this is actually ready?
- what became ambiguous?
- what became stale?

---

## Relationship to GitHub and Code Tracking

Project V should use BYDA to govern implementation traceability, not to become GitHub.

That means Project V should be able to answer:

- what repo, branch, PR, commit, or issue is linked?
- what code-alignment audit has been run?
- what contradictions or drift findings are visible?
- what implementation evidence supports the current planning confidence?

Project V does not need to become a full source-control analytics warehouse.

---

## Data Implication Rule

BYDA in Project V requires explicit records for at least:

- audit runs
- audit gaps
- GitHub linkage records

Other related concepts remain deferred until explicitly promoted through schema governance, such as:

- artifact manifests
- implementation packages
- drift findings
- dedicated audit layer records

---

## Workflow Implication Rule

A project should not move toward implementation merely because someone says it seems ready.

BYDA means the system should preserve:

- what audit type was run
- what questions were asked
- what artifacts or evidence were checked
- what passed
- what failed
- what gaps remain
- what implementation traceability exists
- what became stale later

BYDA should influence:

- planning progression
- readiness confidence
- implementation preparation
- implementation tracking confidence
- handoff confidence
- invalidation and return-to-planning loops

---

## Deferred BYDA Enhancements

The first-pass BYDA core is intentionally small on purpose.

Deferred enhancements should remain planned but not automatically promoted, including:

- numerical scoring
- audit profiles
- temporal drift detection
- reverse-audit checks
- gap effort estimation
- dependency mapping between gaps
- richer audit layer hierarchies
- artifact-aware skip logic
- advanced code-diff intelligence
- historical trend views
- supersedence lineage
- audit weighting models

These should be promoted only when real hands-on Project V use shows the first-pass questioning layer is still too weak.

---

## Final Rule

In Project V, BYDA should be treated as a first-class governance layer for planning, audit, readiness, and implementation traceability.

If it becomes only a document ritual, it is too weak.
If it becomes an everything-system, it is too broad.
