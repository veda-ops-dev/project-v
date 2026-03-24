# Readiness Methodology

## Purpose

This document defines how Project V evaluates readiness.

It exists to answer:

```text
What does Project V mean by readiness, how is readiness evaluated, and what rules prevent readiness from becoming vague theater?
```

Project V treats readiness as a first-class planning concern.
Readiness is not a vibe.
It is an inspectable judgment based on explicit criteria.

---

## Read This With

- `docs/architecture/core/project-v.md`
- `docs/architecture/core/system-invariants.md`
- `docs/architecture/testing/hammer-doctrine.md`
- `docs/architecture/testing/hammer-plan.md`
- `docs/planning/carry-forward-from-project-planner.md`

---

## Core Rule

A Project V record is ready only when the system can explain:

- what was evaluated
- what criteria were used
- what passed
- what failed
- what gaps remain
- what action becomes valid because of the result

If that basis is not recoverable, the readiness claim is weak and should not be trusted.

---

## What Readiness Is

Readiness is a bounded evaluation of whether a Project V record can legitimately move to the next planning or orchestration stage.

Readiness belongs to Project V because it is:

- planning truth
- gating truth
- orchestration truth

Readiness is not:

- observatory truth
- execution truth
- a substitute for implementation outcomes

---

## What Can Be Evaluated

Project V may evaluate readiness for records such as:

- objectives
- initiatives
- work items
- handoffs
- specification packages
- planning packages

The exact set may expand later, but the methodology should remain stable.

---

## Evaluation Outputs

Every readiness evaluation should produce:

- evaluated entity reference
- evaluation type
- result
- rule package or methodology reference
- summary
- created timestamp

Where relevant, it should also produce explicit readiness gaps.

---

## Core Evaluation Dimensions

The initial readiness methodology should evaluate at least these dimensions where applicable.

### 1. Goal clarity

Can the system explain what outcome is being pursued?

Questions:

- is the target outcome explicit?
- is the scope bounded?
- is the record specific enough to act on?

### 2. Structural completeness

Does the record have the required planning structure?

Questions:

- are required fields present?
- are required linked records present?
- is the planning package structurally complete?

### 3. Dependency visibility

Are blocking dependencies visible and classified?

Questions:

- are dependencies known?
- are blockers explicit?
- is hidden dependency risk still high?

### 4. Evidence support

Is there enough support for the planning claim being made?

Questions:

- is supporting evidence linked where needed?
- is the decision basis recoverable?
- are key assumptions unsupported?

### 5. Boundary correctness

Is the work correctly classified as Project V, VEDA, or V Forge work?

Questions:

- does the record stay inside Project V ownership?
- is the target system classification explicit where needed?
- is the handoff boundary clear?

### 6. Execution-handoff readiness

If the work is intended to move toward execution, is the handoff basis actually sufficient?

Questions:

- is the next target system known?
- is the required package complete enough for handoff?
- are unresolved blockers still present?

---

## Result Vocabulary

The first-pass readiness result vocabulary should stay small and explicit.

Recommended values:

- `ready`
- `not_ready`
- `ready_with_warnings`
- `deferred`

If a larger vocabulary is introduced later, it must be justified.

---

## Gap Vocabulary

Readiness gaps should also remain explicit.

Recommended fields include:

- severity
- description
- remediation suggestion
- resolved status

Severity should use a controlled vocabulary.
A small first-pass set is preferred.

---

## Explainability Rule

Every readiness result must be explainable.

That means a reviewer should be able to answer:

- why this result happened
- which rule package was used
- what evidence or structure was missing
- what must change for the result to improve

Opaque pass/fail magic is not acceptable.

---

## Reproducibility Rule

If the same readiness evaluation is run against the same underlying state and the same rules, the result should be the same unless intentional nondeterminism is explicitly documented.

Readiness should favor reproducibility over cleverness.

---

## Advisory Rule

A readiness evaluation may produce advisory findings, warnings, or suggestions.

Those outputs must not silently mutate canonical planning truth.

Explicit action is still required for meaningful state change.

---

## Work Item `readinessState` Synchronization Rule

`WorkItem.readinessState` is a server-managed summary field.

For work items, the field should synchronize like this in the first pass:

- when a new readiness evaluation is created for a work item, the work item''s `readinessState` should be updated in the same transaction to the evaluation result
- the latest non-superseded readiness evaluation for that work item is the governing basis for the summary field
- if the current readiness basis is invalidated because a required audit becomes stale or another material basis change occurs, the work item''s `readinessState` should be reset to `unevaluated` until re-evaluation occurs

This field exists as a useful summary for navigation and filtering.
It must not replace the canonical readiness-evaluation records.

---

## Relationship to State Changes

Readiness does not automatically equal a state transition.

A readiness result may justify a transition, but the transition itself should remain explicit where the domain requires it.

Project V should avoid hidden behavior like:

- evaluate and silently mark as approved
- evaluate and silently create handoff state
- evaluate and silently rewrite planning fields

---

## Archived-Parent Rule

Archived parents should freeze normal forward planning growth beneath them in the first pass.

That means:

- do not create new child objectives, initiatives, or work items under an archived parent record
- do not re-parent active child records under an archived parent
- status-history or governance-side archival actions may still occur where explicitly allowed

If a future workflow needs an exception, it should be modeled explicitly rather than assumed.

---

## Relationship to Handoffs

Handoff readiness is a special case.

A handoff should not be considered ready unless:

- the target system is explicit
- the work package is bounded
- critical gaps are visible
- the basis for transfer is recoverable

Project V may judge a handoff ready.
It does not thereby become the owner of the execution truth that follows.

---

## Relationship to Project Planner Heritage

Project V may inherit useful discipline from Project Planner's readiness and audit posture.

What should be preserved:

- explicit evaluation
- gap visibility
- evidence linkage
- implementation-readiness discipline

What should not be preserved:

- everything-system ownership assumptions
- readiness logic that reaches across bounded system ownership casually

---

## Hammer Requirements

Readiness methodology is not trustworthy until it is hammered.

The hammer suite should verify at least:

- readiness cannot exist without inspectable basis
- gaps are recorded when required
- same inputs produce same results
- advisory outputs do not silently mutate canonical truth
- illegal readiness claims fail correctly

---

## Initial Practical Rule Set

A first-pass record should generally not be called `ready` if any of the following are true:

- the goal is still ambiguous
- required planning structure is missing
- major blockers are unknown or unclassified
- required evidence or rationale is missing
- target-system or handoff classification is unclear
- critical dependencies are unresolved

This should remain a small, hard-to-argue-with rule set at first.

---

## Invalidation Rule

A readiness result may become stale when its governing basis changes materially.

Examples:

- a superseding decision changes scope or sequencing materially
- implementation-linked evidence changes in a way that undermines the original basis
- a dependent audit or linkage record is invalidated

The first-pass system may represent this by requiring re-evaluation rather than by mutating readiness results into a separate stale status, but the invalidation behavior must remain explicit.

---

## Final Rule

Readiness in Project V must be:

- explicit
- inspectable
- reproducible
- bounded
- hard to fake

If a readiness system cannot clearly explain why something is ready, it is not ready.


