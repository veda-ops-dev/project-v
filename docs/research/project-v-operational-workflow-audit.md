# Project V Operational Workflow Audit

**Auditor context:** This audit is conducted against the Project V operational workflow (`docs/architecture/core/project-v-operational-workflow.md`) with full awareness of the complete Project V documentation set as of the current repo state, including schema authority, readiness methodology, system invariants, multi-project doctrine, integration boundary docs, hammer doctrine and plan, API conventions, endpoint governance, glossary, and carry-forward analysis.

**Audit posture:** Strict. This workflow will govern how a multi-project production system processes every idea from intake through implementation. It must survive 100+ projects without degrading into ad hoc operator improvisation.

---

## 1. Executive Judgment

The workflow is structurally sound in its broad sequencing. The fact that it exists at all — as a governed, documented flow rather than an ad hoc improvisation — is correct. The classification-first intake, the readiness gate before handoff, the governance gate before implementation, and the hammer gate before merge are the right major checkpoints in roughly the right order.

However, the workflow has serious operational gaps that will cause drift at scale. The most critical problems are:

1. **Project scope is never explicitly verified after initial classification.** The workflow classifies bounded ownership once at intake and never checks it again. At 100+ projects, scope drift accumulates silently across the planning stages and is only caught (if at all) at the late governance gate — after significant planning work has already been invested.

2. **The workflow has no status history or audit trail step.** System invariant 6.2 requires that status changes and decision/event history stay aligned. The workflow contains multiple implicit state transitions (creating objectives, marking readiness, creating handoffs) but never names a step where status history is recorded. This will be skipped in practice.

3. **Multi-project identity is established too late and too vaguely.** "Create or attach Project record context" is step C in the flow, but there is no explicit verification that the project record exists, that the operator has selected the correct project, or that all subsequent records will be scoped to it. At 100+ projects, this is a scope contamination vector.

4. **The planning decomposition steps (D→E→F) imply strict sequencing that the domain does not require.** The flow forces Objective → Initiative → Work Item as a linear chain. In practice, a work item may be created without a parent initiative (the schema allows optional `initiativeId`). The workflow should reflect the actual domain flexibility without abandoning structural discipline.

5. **The "deferred" path is a dead end.** Step P ("Park / resequence / close loop") has no re-entry point. A deferred item either dies or requires the operator to mentally restart the workflow. This will produce orphaned planning records at scale.

The workflow is approximately 70% of what a governed multi-project system needs. The remaining 30% consists of missing scope enforcement, missing audit trail discipline, missing re-entry paths, and steps that are named too vaguely for LLM-assisted operation.

---

## 2. What Is Strong

**Classification-first intake is correctly positioned.** The flow begins with bounded ownership classification before any planning records are created. This is the right instinct and prevents the most common failure mode: creating records in the wrong system.

**The readiness gate is a real gate, not decoration.** The workflow positions readiness evaluation as a blocking checkpoint with explicit failure paths (not ready → gaps → revise → re-evaluate). The loop-back is correct.

**The governance gate is correctly placed before implementation.** Schema authority, endpoint governance, boundary check, and hammer planning check all occur before implementation begins. This matches the documentation-first posture and prevents spec-code drift from the start.

**The hammer execution gate closes the loop.** Implementation does not produce a "done" state. It must survive hammer execution and regression before being accepted. This is the correct final gate.

**The "ready with warnings" path is honest.** The flow distinguishes between clean readiness, readiness with warnings requiring operator review, and not-ready states. This matches the readiness methodology's result vocabulary (`ready`, `ready_with_warnings`, `not_ready`, `deferred`).

**VEDA and V Forge are referenced correctly at intake.** The flow allows VEDA evidence and V Forge execution context to be linked during intake without making Project V the owner of that truth. The arrows flow into the Project record, not into VEDA or V Forge.

**Implementation-ready outputs are explicit.** The flow names three concrete outputs: schema spec, endpoint family contracts, and hammer module specs. This is more specific than "hand off to implementation" and gives operators and LLMs clear deliverables.

---

## 3. What Is Weak

Ranked from most serious to least serious.

### 3.1 — No project scope verification after classification

The workflow classifies bounded ownership at step B and then never re-verifies scope. Every subsequent step (D through AB) assumes the operator is working in the correct project context. At 100+ projects, this is dangerous.

The multi-project doctrine (invariant: "writes must require explicit project context") requires that project scope be enforced on every mutation. The workflow should reflect this structurally, not leave it to the implementation to enforce.

**Risk:** Cross-project contamination goes undetected until late governance check or, worse, until hammer execution fails post-implementation.

### 3.2 — No status history or audit trail step

System invariant 6.2 says status changes and decision/event history must stay aligned. The workflow contains at least six implicit state transitions:

- Project record creation (C)
- Objective/Initiative/WorkItem creation (D, E, F)
- Readiness evaluation results (J)
- Handoff creation (O)
- Governance pass/fail (R)
- Implementation acceptance (AB)

None of these steps explicitly name a "record status history" or "record state transition" action. The readiness methodology says "explicit action beats silent mutation," but the workflow itself allows silent state progression.

**Risk:** State transitions happen without history records. Debugging and audit at 100+ projects becomes impossible because no one can answer "when did this change and why."

### 3.3 — Planning decomposition is too rigidly sequenced

Steps D → E → F force a strict Objective → Initiative → Work Item chain. The schema authority doc allows `WorkItem.initiativeId` to be optional. An operator may legitimately need to create a work item directly under a project without a parent initiative (e.g., a standalone maintenance task).

The workflow should show the most common path (Objective → Initiative → Work Item) while acknowledging that the domain supports flexible entry points.

**Risk:** Operators and LLMs will either break the workflow to handle legitimate cases, or they will create unnecessary placeholder initiatives to satisfy the rigid chain. Both produce garbage records.

### 3.4 — The "deferred" path is a dead end with no re-entry

Step P ("Park / resequence / close loop") terminates the flow. There is no arrow back to any earlier step. A deferred work item has no governed path to re-enter the workflow.

**Risk:** Deferred items either become orphaned records or are restarted outside the workflow. At 100+ projects, this produces a growing population of parked records with no systematic way to resurface them.

### 3.5 — Step names are too vague for LLM-assisted operation

Several step names would confuse an LLM or require human context to interpret:

- "Create or attach Project record context" — does "attach" mean link to existing or something else?
- "Record decision context if needed" — "if needed" is subjective; an LLM cannot evaluate this
- "Create bounded handoff or implementation package" — these are two different things with different schemas and governance requirements; combining them in one step hides a branch
- "Park / resequence / close loop" — three different actions in one step

**Risk:** LLM operators will interpret vague steps inconsistently. At scale, this produces workflow drift.

### 3.6 — Research and evidence attachment has no completeness check

Step G ("Attach research docs and evidence links") is a single pass-through step with no validation. The readiness methodology requires evidence support as a core evaluation dimension, but the workflow does not check whether evidence is sufficient before proceeding to dependencies and decisions.

**Risk:** Items reach the readiness gate with minimal or missing evidence, fail, loop back, and waste a full readiness evaluation cycle on something that should have been caught earlier.

### 3.7 — The governance check treats four sub-checks as parallel but they have dependencies

Steps Q1–Q4 (schema authority, endpoint governance, boundary, hammer planning) are shown as parallel branches feeding into a single decision node R. In practice, these checks have dependencies: schema authority must pass before endpoint governance can be meaningfully evaluated (endpoints are shaped by schema), and boundary checks depend on knowing the schema and endpoint shape. Hammer planning depends on all three.

**Risk:** Operators run all four checks simultaneously, find failures in schema authority, fix them, and then discover that the endpoint governance and hammer planning checks need to be re-run because the inputs changed. This produces wasted cycles.

### 3.8 — No explicit step for controlled vocabulary validation

The schema authority doc requires controlled vocabulary for `WorkItem.targetSystemClassification`, `Handoff.targetSystemClassification`, and other fields. The workflow never names a step where controlled vocabulary compliance is verified. This is currently hidden inside "governance check" but deserves explicit attention because vocabulary drift is a documented failure mode in LLM-assisted development.

### 3.9 — The flow has no feedback loop from implementation back to planning

After implementation begins (X), the only path is forward through hammer execution (Y) or back to fix drift (AA → Y). There is no governed path from implementation back to the planning stages (D through I) for cases where implementation reveals that the specification was wrong.

The carry-forward doc keeps "research-to-task traceability" and the system invariants require decision traceability. But the workflow provides no governed mechanism for "we started implementation, discovered the spec is wrong, and need to revise the planning records."

**Risk:** Implementation-discovered spec errors are fixed in code without updating the planning records. Spec-code drift begins from the first implementation cycle.

---

## 4. Missing Steps

### 4.1 — Add: "Verify project scope context" after step C, before step D

**Where:** Between C (Create or attach Project record) and D (Create or refine Objective).

**What it does:** Explicitly confirms that the operator is working in the correct project context, that the project record exists, is active, and that all subsequent records will be scoped to this project.

**Why:** Multi-project doctrine requires explicit project context on all writes. This step makes that requirement visible in the workflow rather than relying on implementation to enforce it silently.

### 4.2 — Add: "Record status history" as a companion to every state-creating or state-changing step

**Where:** As a parallel obligation alongside steps C, D, E, F, J, O, Q→R, X, and AB.

**What it does:** Every time a record is created, a status changes, or a readiness result is produced, the corresponding status history entry is also recorded.

**Why:** System invariant 6.2. Without this, the workflow allows silent state progression.

### 4.3 — Add: "Evidence sufficiency pre-check" between G and H

**Where:** After G (Attach research docs and evidence links), before H (Record dependencies).

**What it does:** Lightweight check that minimum evidence thresholds are met before proceeding. Not a full readiness evaluation — just a structural completeness check (e.g., does the work item have at least one evidence link? Is the decision basis recoverable?).

**Why:** Prevents items from reaching the readiness gate with obviously insufficient evidence, reducing wasted evaluation cycles.

### 4.4 — Add: "Deferred item re-entry review" as a periodic or triggered workflow

**Where:** As a governed re-entry path from step P back to step D or F.

**What it does:** Deferred items are periodically reviewed. If conditions have changed (blockers resolved, priorities shifted), the item re-enters the workflow at the appropriate planning stage.

**Why:** Without this, deferred items become orphans. At 100+ projects with dozens of deferred items per project, this produces a significant population of unmanaged planning records.

### 4.5 — Add: "Spec revision gate" as a governed path from implementation back to planning

**Where:** As a branch from step AA (Fix model / contract / implementation drift) back to step D or the governance check (Q).

**What it does:** When implementation reveals a specification error, the fix path is not just "fix the code" but "revise the planning records, re-run affected governance checks, and then resume implementation."

**Why:** Without this, implementation-discovered problems are fixed only in code, and the planning records drift out of alignment with the actual system.

### 4.6 — Add: "Controlled vocabulary compliance check" as an explicit sub-step of governance

**Where:** Inside the governance check block (Q), as a named sub-check alongside Q1–Q4.

**What it does:** Verifies that all records using controlled vocabulary fields (`targetSystemClassification`, status values, readiness result vocabulary, gap severity vocabulary) use valid values from the governed vocabulary.

**Why:** Vocabulary drift is a documented failure mode. The glossary and schema authority both define controlled vocabularies. The workflow should verify compliance explicitly.

---

## 5. Ordering Problems

### 5.1 — Steps D → E → F should be reframed as "Planning decomposition" with flexible entry

Currently the flow forces Objective → Initiative → Work Item as a strict linear sequence. This should be reframed as a planning decomposition phase where the entry point depends on the work being classified:

- New strategic direction → start at Objective
- New bounded work body → start at Initiative (may or may not have a parent Objective yet)
- Standalone concrete task → start at Work Item (may not need an Initiative)

The workflow should show the most common path while naming the alternatives.

### 5.2 — Governance sub-checks (Q1–Q4) should be sequenced, not parallel

Schema authority check (Q1) should complete before endpoint governance check (Q2), because endpoint design depends on schema shape. Boundary check (Q3) can run in parallel with Q1 or Q2. Hammer planning check (Q4) should run last, because hammer coverage depends on knowing the schema, endpoints, and boundary shape.

Recommended order: Q1 → (Q2 + Q3 in parallel) → Q4.

### 5.3 — Step O should be split into two distinct steps

"Create bounded handoff or implementation package" combines two different outcomes:

- A **handoff** transitions work to another bounded system (V Forge). It requires target system classification, handoff readiness basis, and boundary-honest framing.
- An **implementation package** stays inside Project V's owned scope (e.g., schema changes, endpoint additions). It requires governed spec output.

These have different schemas, different governance requirements, and different downstream paths. They should be separate steps with an explicit branch.

### 5.4 — Step I (Record decision context) should not be "if needed"

The "if needed" qualifier makes this step optional based on operator judgment. At scale and under LLM assistance, "if needed" means "usually skipped." The step should be reframed as: "Record decision context for any non-trivial scope, priority, or dependency decision made during planning decomposition." The operator may skip it only for trivially obvious cases, and that skip should itself be a conscious decision, not a default.

---

## 6. Multi-Project Audit

**Verdict: The workflow is not yet safe for 100+ projects. The core risk is scope enforcement, not structural sequencing.**

### What works for multi-project

The classification-first intake (step B) is correct. The readiness gate and governance gate are project-scoped by the methodology docs. The schema authority enforces `projectId` on all project-scoped tables.

### What breaks at 100+ projects

**No explicit project context verification in the workflow.** The multi-project doctrine says "writes must require explicit project context" and "implicit project inference is dangerous at 100+ projects." The workflow establishes project context once (step C) and never verifies it again. At 100+ projects, an operator switching between projects mid-workflow will contaminate records.

**No explicit cross-project dependency prohibition in the workflow.** The multi-project doctrine says "cross-project contamination must fail." Step H ("Record dependencies and blockers") does not mention project scope. An operator creating a dependency between records in different projects will not be caught until the governance gate or hammer execution — long after the error was introduced.

**The "deferred" dead end accumulates across projects.** At 100+ projects with even 5 deferred items each, the system accumulates 500+ orphaned planning records with no governed re-entry path. This is a maintenance burden that scales linearly with project count.

**No project archival or completion step.** The workflow covers idea-to-merge for individual work items but says nothing about project-level lifecycle. At 100+ projects, some projects will be completed, archived, or abandoned. The workflow provides no governed path for closing out a project's planning records, and the schema authority has no soft-delete or archive policy.

**Ordering determinism is not mentioned.** The multi-project doctrine and system invariants require deterministic ordering on all list surfaces. The workflow produces records (objectives, initiatives, work items, readiness evaluations) but never mentions ordering. At 100+ projects, non-deterministic ordering of work items across projects will produce inconsistent operator experiences.

### Specific recommendations for multi-project safety

1. Add an explicit "verify project scope" step after project record attachment.
2. Add a project-scope check to the dependency recording step (H).
3. Add a governed re-entry path for deferred items.
4. Add a project-level completion/archival workflow (can be a separate document, but should be referenced from this one).
5. Add ordering requirements to any step that produces list-queryable records.

---

## 7. Readiness and Governance Audit

### Readiness positioning

**Verdict: Readiness is correctly positioned but under-specified in the workflow.**

The readiness gate (step J) is in the right place — after planning decomposition and evidence attachment, before handoff or implementation package creation. The loop-back (not ready → gaps → revise → re-evaluate) is correct.

**Weakness 1: Only one readiness gate exists in the main flow.** The workflow runs readiness once, before handoff/implementation package. There is no readiness check after governance and before implementation begins. An item could pass readiness, fail governance, be revised, and proceed to implementation without being re-evaluated for readiness after the revisions. The governance loop-back (S → D) sends the item back to planning but does not re-trigger readiness evaluation.

**Recommendation:** Add a lightweight readiness re-check after the governance gate passes (between R→Yes and T) to verify that governance-driven revisions did not invalidate the readiness basis.

**Weakness 2: The readiness methodology defines six evaluation dimensions, but the workflow does not name which dimensions are evaluated at this gate.** An LLM running the readiness evaluation does not know from the workflow alone whether to evaluate all six dimensions or a subset. The readiness methodology doc defines the dimensions, but the workflow should reference which dimensions are mandatory at this gate.

**Weakness 3: The "ready with warnings" path puts the decision entirely on the operator.** There is no guidance on what kind of warnings are acceptable to proceed with versus which should block. At scale, this will produce inconsistent decisions across projects.

### Governance positioning

**Verdict: Governance is correctly positioned but the sub-checks need sequencing and the gate needs teeth.**

The governance check (Q) is correctly placed before implementation-ready spec production (T). The four sub-checks (schema authority, endpoint governance, boundary, hammer planning) cover the right concerns.

**Weakness 1: The governance gate has no numerical threshold.** The readiness gate has a clear pass/fail based on the readiness methodology. The governance gate (R: "Governed and valid?") is a subjective judgment. There is no scoring, no severity system, and no explicit definition of what "governed and valid" means. An LLM cannot evaluate this deterministically.

**Recommendation:** Define governance gate criteria with the same rigor as readiness gate criteria. At minimum: zero blocking governance findings, all four sub-checks completed, and all required artifacts present.

**Weakness 2: The governance gate does not check for controlled vocabulary compliance.** See Missing Step 4.6 above.

**Weakness 3: The governance gate does not verify that the readiness evaluation is still valid.** If the governance loop-back (S → D) causes planning revisions, the prior readiness evaluation may be stale. The governance gate should verify readiness evaluation currency.

---

## 8. Hammer Audit

**Verdict: Hammer is correctly positioned as the final gate, but the workflow does not provide enough structure for hammer planning to produce actionable specs.**

### What is strong

The hammer execution gate (Y) is the right final checkpoint. The failure path (Z→No → AA → Y) creates a genuine loop that prevents drift-infected implementation from being accepted. The implementation-ready outputs explicitly include "hammer module specs" (W), which means hammer planning is a first-class deliverable, not an afterthought.

### What is weak

**Weakness 1: Hammer planning (Q4) runs once, at governance time.** If implementation reveals new boundary conditions, edge cases, or failure modes, there is no governed path to update the hammer module specs. The fix loop (AA → Y) fixes "model / contract / implementation drift" but does not explicitly include "update hammer specs to cover the newly discovered failure mode."

**Recommendation:** Step AA should explicitly include "update hammer module specs if new failure modes are discovered."

**Weakness 2: The workflow does not distinguish between hammer types.** The hammer doctrine defines six categories (persistence, contract, mutation-boundary, readiness, boundary, determinism). The workflow treats "hammer execution" as a single monolithic step. At scale, different work items will require different hammer categories. The workflow should indicate which hammer categories are required based on the work item type.

**Weakness 3: No scale isolation probe is named.** The hammer plan (per the previous docs audit) has no "populate N projects and verify deterministic behavior" probe. The workflow inherits this gap — there is no step that says "verify this implementation works correctly under realistic multi-project population."

**Weakness 4: Rollback behavior is not named in the workflow.** The hammer doctrine says "probe rollback deliberately." The workflow's fix loop (AA → Y) implies fixing forward. There is no explicit step for "if hammer execution reveals a fundamental problem, roll back the implementation and return to governance." The workflow should have a governed rollback path, not just a fix-forward loop.

**Recommendation:** Add a rollback branch from Z→No that goes back to the governance check (Q) when the failure is fundamental rather than a minor drift fix.

---

## 9. Tightening Recommendations

### Recommendation 1: Add explicit project scope verification step

After step C, before any planning records are created. This step should verify: project record exists, project is active, operator has confirmed the correct project context. This is the single highest-value change for multi-project safety.

### Recommendation 2: Replace "if needed" qualifiers with explicit trigger conditions

Step I says "Record decision context if needed." Replace with: "Record decision context when any of the following occurred during planning decomposition: scope was narrowed or expanded, priority was set or changed, a dependency was introduced, a blocker was identified, or a non-obvious classification choice was made."

### Recommendation 3: Split step O into "Create handoff" and "Create implementation package"

These are different outputs with different schemas, different governance requirements, and different downstream paths. Name them separately with an explicit branch condition.

### Recommendation 4: Sequence governance sub-checks

Replace parallel Q1–Q4 with: Q1 (schema authority) → Q2 (endpoint governance) + Q3 (boundary check) → Q4 (hammer planning) + Q5 (controlled vocabulary compliance). This reflects the actual dependency chain.

### Recommendation 5: Add a readiness re-check after governance pass

Between R→Yes and T. This catches cases where governance-driven revisions invalidated the readiness basis.

### Recommendation 6: Add a governed deferred-item re-entry path

Step P should have an arrow back to step D (or the appropriate planning stage) with a trigger condition: "when blockers are resolved, priorities change, or a periodic review surfaces the item."

### Recommendation 7: Add an implementation-to-planning revision path

From step AA, add a governed branch back to governance (Q) or planning (D) for cases where implementation reveals fundamental specification errors that cannot be fixed by patching code alone.

### Recommendation 8: Name status history recording as a workflow obligation

Add a standing rule to the workflow: "Every step that creates a record, changes a status, or produces a readiness/governance result must also produce a corresponding status history entry." This can be a workflow-level rule rather than a separate step at every node.

### Recommendation 9: Add explicit ordering requirements to record-creating steps

Steps D, E, F, G, and O all create records that will appear in list surfaces. The workflow should note that all created records must support deterministic ordering per system invariant 5.1.

### Recommendation 10: Add a rollback path from hammer failure to governance

When hammer failure reveals a fundamental problem (not just minor drift), the workflow should support returning to the governance check (Q) rather than only fixing forward. Name the criteria for rollback vs. fix-forward explicitly.

---

## 10. Revised Workflow

This is a revised step-by-step workflow outline incorporating the audit findings. It preserves the original structure where it was sound and adds the missing steps, re-entry paths, and tightening changes identified above.

### Phase A: Intake and Classification

```
A1. Idea / problem / opportunity arrives.
A2. Classify bounded ownership:
    → Project V planning/orchestration → proceed to B
    → Needs VEDA observability input → request/link VEDA evidence, then proceed to B
    → Needs V Forge execution context → reference V Forge boundary, then proceed to B
    → Not Project V ownership → route to correct system, exit this workflow
```

### Phase B: Project Context Establishment

```
B1. Create or locate existing Project record.
B2. Verify project scope context:
    - project record exists and is active
    - operator confirms correct project identity
    - all subsequent records will be scoped to this project
    Record: status history entry for project context attachment.
```

### Phase C: Planning Decomposition

```
C1. Determine entry point based on work classification:
    → New strategic direction → create or refine Objective (C2)
    → New bounded work body → create or refine Initiative (C3)
    → Standalone concrete task → create or refine Work Item (C4)

C2. Create or refine Objective.
    - must belong to verified project scope
    - record status history
C3. Create or refine Initiative.
    - must belong to verified project scope
    - link to parent Objective if applicable
    - record status history
C4. Create or refine Work Item.
    - must belong to verified project scope
    - link to parent Initiative if applicable
    - classify target system using controlled vocabulary
    - record status history
```

### Phase D: Evidence, Dependencies, and Decisions

```
D1. Attach research docs and evidence links.
    - all evidence must reference the correct project scope
    - evidence links must remain directional and honest (not ownership claims)
D2. Evidence sufficiency pre-check:
    - does the work item have minimum required evidence?
    - is the decision basis recoverable?
    - if insufficient → return to D1 before proceeding
D3. Record dependencies and blockers.
    - verify all dependency targets belong to the same project
      (or are explicitly modeled cross-project exceptions)
    - classify blockers explicitly
D4. Record decision context.
    Trigger: record when any of the following occurred:
    - scope was narrowed or expanded
    - priority was set or changed
    - dependency was introduced
    - blocker was identified
    - non-obvious classification choice was made
    - boundary ownership question was resolved
    Skip only for trivially obvious cases.
```

### Phase E: Readiness Evaluation

```
E1. Run readiness evaluation.
    - evaluate against readiness methodology dimensions:
      goal clarity, structural completeness, dependency visibility,
      evidence support, boundary correctness, execution-handoff readiness
    - record evaluation result, rule package reference, and basis
    - record status history

E2. Branch on result:
    → not_ready → E3
    → ready_with_warnings → E4
    → ready → F1
    → deferred → E6

E3. Not ready:
    - create readiness gaps with severity and remediation suggestions
    - revise docs / scope / evidence / dependencies as indicated
    - return to E1

E4. Ready with warnings:
    - present warnings to operator with explicit guidance:
      advisory warnings (non-blocking) vs. significant warnings (should block unless justified)
    - operator reviews and decides
    → proceed → F1
    → do not proceed → return to D1 or C (appropriate planning stage)

E5. (Standing rule) Record status history for all readiness results.

E6. Deferred:
    - park the item with explicit deferral reason
    - record deferral in status history
    - item enters deferred review pool
    - governed re-entry: when blockers resolve, priorities change,
      or periodic review triggers, item re-enters at Phase C or D
```

### Phase F: Handoff or Implementation Package

```
F1. Determine output type:
    → Work targets another bounded system (V Forge, etc.)
      → F2: Create bounded handoff
    → Work targets Project V-owned implementation (schema, endpoints, etc.)
      → F3: Create implementation package

F2. Create bounded handoff.
    - source project identity
    - source record identity
    - target system classification (controlled vocabulary)
    - handoff type
    - readiness basis summary or reference
    - rationale
    - status
    - record status history
    - verify target system classification is valid

F3. Create implementation package.
    - scope the package to verified project context
    - include: schema change requirements, endpoint requirements,
      hammer coverage requirements, boundary requirements
    - record status history
```

### Phase G: Governance Gate

```
G1. Schema authority check.
    - does the proposed schema change (if any) satisfy the schema change gate?
    - bounded ownership, written justification, migration plan,
      multi-project contamination review
    - controlled vocabulary compliance for all enum/status fields
    → pass → G2
    → fail → return to Phase C with specific governance findings

G2. Endpoint governance check + Boundary check (may run in parallel).
    - does the proposed endpoint change (if any) satisfy the endpoint change gate?
    - does the proposed work respect bounded system boundaries?
    - are cross-system references explicit and honest?
    → pass → G3
    → fail → return to Phase C with specific governance findings

G3. Hammer planning check + Controlled vocabulary compliance check.
    - are hammer module specs defined for the proposed changes?
    - do all records use valid controlled vocabulary values?
    → pass → G4
    → fail → return to Phase C with specific governance findings

G4. Readiness currency check.
    - is the readiness evaluation still valid after any governance-driven revisions?
    - if revisions occurred during governance loop-back, re-run readiness evaluation (return to E1)
    → readiness still valid → G5
    → readiness stale → return to E1

G5. Governance gate passes.
    - record governance pass in status history
```

### Phase H: Implementation-Ready Spec Production

```
H1. Produce concrete schema spec (if applicable).
H2. Produce endpoint family contracts (if applicable).
H3. Produce hammer module specs.
    - name invariants being tested
    - name valid and invalid paths
    - name which hammer categories apply
      (persistence, contract, mutation-boundary, readiness, boundary, determinism)

All specs must reference the governing project scope.
```

### Phase I: Implementation

```
I1. Implementation begins from governed specs.
I2. If implementation reveals specification errors:
    → minor drift: fix implementation, update spec, continue
    → fundamental spec error: return to Phase G (governance gate)
       with a recorded decision explaining the revision
I3. Record status history for implementation milestones.
```

### Phase J: Hammer Execution Gate

```
J1. Run hammer execution against implementation.
    - run applicable hammer categories
    - verify both valid and invalid paths

J2. Branch on result:
    → pass → J4
    → fail (minor drift) → J3a
    → fail (fundamental) → J3b

J3a. Fix model / contract / implementation drift.
    - update hammer module specs if new failure modes discovered
    - fix implementation
    - return to J1

J3b. Fundamental failure requiring rollback.
    - return to Phase G (governance gate) for re-evaluation
    - record rollback decision in status history

J4. Hammer passes.
    - bounded system accepted / ready to merge
    - record final acceptance in status history
```

### Standing Workflow Rules

```
Rule 1: Every step that creates a record, changes a status, or produces
        an evaluation result must also produce a status history entry.

Rule 2: All records created in this workflow must be scoped to the
        verified project context established in Phase B.

Rule 3: All list-queryable records must support deterministic ordering
        per system invariant 5.1.

Rule 4: Controlled vocabulary fields must use values from the governed
        vocabulary at all times. Invalid vocabulary values must be
        rejected at creation, not fixed later.

Rule 5: Deferred items must be periodically reviewed for re-entry
        eligibility. The re-entry trigger conditions are: blocker
        resolution, priority change, or scheduled periodic review.
```

---

*End of audit.*
