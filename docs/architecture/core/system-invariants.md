# Project V System Invariants

## Purpose

This document defines the non-negotiable system invariants of Project V.

These invariants are architectural constraints, not implementation preferences.

If a proposed change violates an invariant in this document, the change is incorrect.

---

## 1. Bounded Ownership Invariants

### 1.1 Project V is orchestration-only

Project V owns planning and orchestration truth.

Project V may own:

- objectives
- initiatives
- work decomposition
- readiness records
- decision records
- handoff records
- planning-oriented research traceability

Project V does not own:

- observatory truth
- execution artifact truth
- publishing workflow truth

### 1.2 Project V must not impersonate VEDA

Project V may reference VEDA observations.
It must not become the canonical owner of those observations.

Observed external reality remains owned by VEDA.

### 1.3 Project V must not impersonate V Forge

Project V may coordinate execution handoffs.
It must not become the canonical owner of draft state, production workflow, or produced artifacts.

---

## 2. Scope and Isolation Invariants

### 2.1 Planning records must remain inside Project V ownership

All Project V planning records must be stored in Project V-owned persistence.

Project V must not rely on ad hoc cross-system tables as a hidden extension of its domain.

### 2.2 Cross-system references must stay explicit

When Project V references VEDA or V Forge entities, the reference must be explicit.

No hidden cross-system ownership transfer is allowed.

### 2.3 Cross-system writes must remain bounded

Project V must not write directly into another bounded system's canonical tables as a convenience shortcut.

Cross-system interaction should occur through explicit interfaces, handoff records, import flows, or other deliberate boundary mechanisms.

---

## 3. Readiness and Audit Invariants

### 3.1 Readiness must be inspectable

If Project V claims that a work item, initiative, or package is ready, the basis for that readiness must be inspectable.

The system must make it possible to recover:

- what was evaluated
- what passed
- what failed
- what gaps remain

### 3.2 Audit outputs must not silently mutate canonical planning truth

Audit or readiness evaluation may produce results, warnings, and recommendations.

Those outputs must not silently rewrite canonical planning truth without explicit action.

### 3.3 Gating must remain explainable

A readiness or planning gate must be explainable to both humans and LLM-assisted operator surfaces.

Opaque pass/fail magic is not acceptable.

---

## 4. Decision and Traceability Invariants

### 4.1 Significant decisions must be recoverable

Where Project V records a meaningful planning or orchestration decision, the decision and its rationale should be recoverable.

### 4.2 Evidence links must remain directional and honest

If Project V links research, observations, or notes to a planning decision or work item, those links must not overclaim.

A supporting reference is not the same thing as canonical ownership of the referenced truth.

### 4.3 Derived summaries are not canonical truth unless explicitly promoted

Generated summaries, synthesis notes, and convenience views may exist.

Canonical planning truth must remain explicit.
Derived artifacts must not silently replace it.

---

## 5. Determinism Invariants

### 5.1 List and queue surfaces must have deterministic ordering

All list-like Project V surfaces must define deterministic ordering.
No surface may rely on implicit database ordering.

### 5.2 Readiness evaluation must be reproducible against the same inputs

If the same readiness evaluation runs against the same state and the same rules, it should produce the same result unless intentional nondeterminism is explicitly documented.

### 5.3 Context assembly should prefer reproducibility over cleverness

Project V may assemble context for operators and LLMs.
That assembly should prefer stable, inspectable retrieval over clever but unstable heuristics.

---

## 6. Transaction and State Invariants

### 6.1 Multi-write state changes must be atomic

Any Project V operation that changes persisted state across multiple writes must execute atomically.

Partial writes for important orchestration state are forbidden.

### 6.2 Status changes and decision/event history must stay aligned

If a state transition requires a decision record, status history record, or event-style record, those writes must stay aligned.

It must not be possible for:

- state to change without required history
- history to exist without the corresponding state change

### 6.3 Explicit action beats silent mutation

Project V should prefer explicit state transitions over silent behind-the-scenes rewriting.

Operators and LLM tooling must be able to understand what changed and why.

---

## 7. Data Boundary Invariants

### 7.1 Project V has its own database boundary

Project V should own its canonical persistence inside its own database.

The baseline ecosystem database shape is:

- `project_v`
- `veda`
- `v_forge`

all on the same Postgres cluster.

### 7.2 Shared infrastructure does not justify shared truth

Project V may share infrastructure with other systems.
That does not permit domain collapse or mixed canonical ownership.

### 7.3 Cross-database convenience must not weaken boundaries

If a shortcut makes the system easier to hack together but harder to classify, inspect, or reason about safely, the shortcut is incorrect.

---

## 8. Operator Surface Invariants

### 8.1 Operator surfaces must expose bounded truth honestly

MCP, CLI, editor, or other operator-facing surfaces must describe Project V capabilities honestly.

They must not imply that Project V owns observatory or execution truth that actually belongs elsewhere.

### 8.2 Proposal visibility is allowed; silent authority escalation is not

Project V may support suggestions, recommendations, and planning proposals.

Those proposals must not silently become canonical truth without explicit operator action or explicit system rules.

### 8.3 LLM assistance must reinforce boundaries, not blur them

Project V is being built for LLM-assisted use.
That means prompts, tools, and generated workflows must reinforce bounded ownership rather than reintroduce blob behavior.

---

## 9. Testing and Verification Invariants

### 9.1 Planning and gating rules must be testable

Any important readiness, sequencing, or orchestration rule must be testable.

### 9.2 Boundary violations should be probeable

It should be possible to verify that Project V does not accidentally:

- own VEDA truth
- own V Forge truth
- perform hidden cross-system writes
- misreport readiness without evidence

### 9.3 Repeatability matters

If a rule, queue, or gate is important enough to trust, it should be repeatable enough to verify.

---

## Final Principle

Project V is a bounded planning and orchestration system.

It is not an observatory.
It is not a production workflow system.
It is not a convenience blob.

Bounded ownership matters.
Readiness must be explainable.
State changes must be explicit.
Cross-system clarity must be preserved.
