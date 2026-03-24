# Audit Evaluation Rules

## Purpose

This document defines the first-pass BYDA audit rules that Project V should use.

It exists to answer:

```text
What audit types exist, what questions do they ask, what counts as pass/fail/warning/stale, what creates audit gaps, and what invalidates audit confidence later?
```

Read this with:

- `docs/architecture/core/byda-in-project-v.md`
- `docs/architecture/core/project-v-lifecycle.md`
- `docs/architecture/core/project-v-operational-workflow.md`
- `docs/architecture/core/readiness-evaluation-rules.md`
- `docs/architecture/data/audit-and-gap-model.md`
- `docs/architecture/data/controlled-vocabularies.md`
- `docs/architecture/data/schema-authority.md`
- `docs/architecture/data/schema-specification.md`
- `docs/architecture/data/polymorphic-reference-enforcement.md`
- `docs/architecture/data/code-linkage-and-code-visibility.md`
- `docs/architecture/core/implementation-traceability.md`

---

## Core Rule

BYDA in Project V should behave like a governed questioning and audit layer.

It should not ask random questions.
It should ask explicit questions tied to:

- audit type
- lifecycle phase
- declared artifacts or governed expectations
- readiness and implementation consequences

If the system cannot explain what was asked and why the result was produced, the audit layer is too weak.

---

## Audit Execution Model

In the first pass, an audit may be operator-triggered, but the canonical audit result is server-computed from governed audit rules.

That means:

- an operator or workflow may request that an audit run
- the caller does not get to set the canonical `result`
- the server must execute the governed audit checks, compute the canonical result, and create gaps where required

If the server is not computing the result from governed checks, the audit model is too weak.

---

## First-Pass Audit Types

The first-pass BYDA core should treat these audit types as real and implementable:

- `research`
- `planning`
- `implementation_readiness`
- `code_alignment`
- `handoff`
- `hygiene`

Not every project must use every audit type on day one.
But the first-pass rule set should define what each type means.

---

## Result Set

Allowed audit results are governed by:

- `docs/architecture/data/controlled-vocabularies.md`

First-pass values:

- `pass`
- `fail`
- `warning`
- `stale`

---

## Rule Order

Evaluate in this order:

### 1. Scope validity
If the target entity is missing, invalid, or out of project scope, fail the request rather than producing an audit result.

### 2. Audit applicability
If the requested audit type does not apply to the target entity or lifecycle stage, fail the request rather than producing fake output.

### 3. Required-basis validity
If the audit lacks the minimum required basis to ask its questions honestly, return `fail` and create gaps where appropriate.

### 4. Hard-failure conditions
If one or more hard-failure rules are true, return `fail`.

### 5. Warning conditions
If no hard-failure rule is true but one or more warning conditions are true, return `warning`.

### 6. Pass condition
If no hard-failure rule or warning condition is true, return `pass`.

### 7. Staleness
`stale` is not a normal first-run result.
It is a later invalidation state applied when the original audit basis is no longer trustworthy.

---

## Audit Questions By Type

## 1. `research`

### Primary questions
- Is the project or target record scoped clearly enough to justify continued planning?
- Is there enough evidence or rationale to support the current direction?
- Are obvious blockers or dependencies visible rather than hidden?
- Is bounded ownership between Project V, VEDA, and V Forge still clear?

### Hard-failure examples
- material evidence basis is missing
- ownership is ambiguous
- the problem statement is too vague to plan against

### Warning examples
- rationale exists but is still thin
- dependency visibility is incomplete but not yet blocking
- evidence is present but weak in one advisory area

## 2. `planning`

### Primary questions
- Is the planning stack structurally valid for the intended phase?
- Are key planning records, decisions, and dependencies explicit enough to govern work?
- Do governed docs agree on the current planning shape?

### Hard-failure examples
- structurally required planning context is missing
- key planning docs materially disagree
- target system or scope remains materially unclear

### Warning examples
- minor planning detail is incomplete
- one non-blocking doc inconsistency exists

## 3. `implementation_readiness`

### Primary questions
- Is the target ready to move toward implementation or implementation tracking?
- Are blocking readiness and audit issues resolved?
- Is implementation linkage posture clear enough where required?
- Do governed contracts and planning docs agree enough to proceed?

### Hard-failure examples
- required readiness gate is still failing
- blocking audit gap remains open
- implementation linkage posture is missing where required
- cross-artifact contract disagreement is material

### Warning examples
- non-blocking advisory gap remains open
- implementation linkage is present but not yet as rich as preferred

## 4. `code_alignment`

### Primary questions
- Is there bounded GitHub or code-linked evidence for the target work?
- Does the linked code evidence appear to match the governed intent?
- Is obvious spec-to-code drift visible?
- Has the audit basis been invalidated by later linkage changes?

### Hard-failure examples
- required GitHub or code linkage is missing
- linked code evidence materially contradicts governed intent
- material code drift is visible against governed contracts or docs

### Warning examples
- linkage exists but is incomplete in one advisory area
- evidence is present but still thin or partially summarized

## 5. `handoff`

### Primary questions
- Is the handoff target explicit and bounded?
- Does the handoff basis align with readiness and audit state?
- Are unresolved issues still visible to the receiving boundary?

### Hard-failure examples
- handoff target remains ambiguous
- readiness and audit basis materially disagree
- blocking gap remains unresolved

### Warning examples
- the handoff may proceed but still carries advisory caveats

## 6. `hygiene`

### Primary questions
- Are the governed docs and records staying clean, explicit, and non-contradictory?
- Is ambiguity, TODO language, or drift accumulating?

### Hard-failure examples
- material ambiguity prevents safe implementation or governance
- stale contradictions remain unresolved across authority docs

### Warning examples
- ambiguity exists but is still advisory rather than blocking
- minor documentation debt is visible

---

## Gap Creation Rules

An audit should create one or more `AuditGap` records when the audit exposes a concrete deficiency that should remain recoverable.

First-pass posture:

- hard-failure conditions should normally create at least one audit gap
- warning conditions may create advisory or minor gaps
- purely informational observations should not automatically become gaps

Audit gaps should preserve:

- what failed or weakened the audit
- why it matters
- what remediation direction exists
- whether it remains open, resolved, or invalidated

---

## Cross-Artifact Consistency Checks

BYDA becomes meaningfully useful only if it checks for contradictions across governed artifacts.

First-pass cross-artifact checks must include at least the following, bound to the audit types that apply them:

| Check | Applies To Audit Types |
|---|---|
| `schema-authority` ↔ `schema-specification` | `planning`, `implementation_readiness`, `hygiene` |
| `schema-specification` ↔ `controlled-vocabularies` | `planning`, `implementation_readiness`, `hygiene` |
| `API contracts` ↔ `schema-specification` | `implementation_readiness`, `code_alignment`, `hygiene` |
| `status-transitions` ↔ explicit status-route expectations | `planning`, `implementation_readiness`, `hygiene` |
| `polymorphic-reference rules` ↔ allowed entity-type vocabularies | `planning`, `implementation_readiness`, `hygiene` |
| `GitHub linkage rules` ↔ `implementation-traceability rules` | `code_alignment`, `handoff` |

### Applicability note on API contracts

API contract docs (`docs/api/`) are listed as deferred output in the documentation roadmap. Until they exist, the `API contracts <-> schema-specification` check cannot run. When running `implementation_readiness` or `code_alignment` audits before API docs exist, the audit must note the absence as an advisory gap rather than treating it as a blocking cross-artifact contradiction.

### Contradiction severity

If a material contradiction exists between two checked artifacts, the audit must return `fail`.
If the contradiction is minor and non-blocking, it may return `warning`.

---

## Ambiguity Detection Rules

BYDA must explicitly detect implementation-dangerous ambiguity in governed docs.

First-pass ambiguity detection must flag terms such as:

- appropriate
- sufficient
- reasonable
- as needed
- properly
- later
- TBD
- TODO

Flagging a term triggers a classification decision.

### Material ambiguity (must fail the audit)

Ambiguity is material when it affects any of the following:

- a field or rule that governs a hard-block readiness condition
- a status transition rule or allowed/forbidden classification
- a target-system or boundary classification
- a readiness or audit gate condition
- a constraint or validation rule that the hammer suite would probe

Examples:

- "set a **reasonable** timeout" in a schema spec → material; a timeout value is a hard rule, not a preference
- "use **appropriate** credentials" in a security doc → material; authentication rules are implementation gates
- "**TBD**: decide retry behavior" in an API contract → material; missing contract terms block safe implementation

### Advisory ambiguity (may produce a warning or minor gap)

Ambiguity is advisory when it appears in:

- non-normative explanatory text that does not govern a rule
- prose rationale or context sections
- guidance that describes a recommendation rather than a requirement
- areas where the adjacent concrete rule makes the intent sufficiently recoverable

Examples:

- "this pattern is generally **sufficient** for most projects" in a rationale paragraph → advisory
- "**TODO**: add examples here" in an explanatory section that already has governing rules → advisory

### Ambiguity detection is a classification step, not a blanket pass/fail

Not every flagged term fails the audit. The audit must classify each finding as material or advisory based on the rules above. Only material findings produce a `fail`. Advisory findings may produce a `warning` or minor gap.

---

## Staleness / Invalidation Rules

An audit result should become `stale` when its original basis is materially invalidated later.

First-pass triggers include:

- a superseding decision is recorded
- a material schema or contract change occurs after the audit
- a backward status rollback invalidates prior confidence
- implementation-linked evidence changes after the audit in a material way
- GitHub linkage changes in a way that invalidates the audited basis

`stale` means the prior audit result should not be trusted as current.
It does not magically convert the system into `pass` or `fail`.
It means re-audit is required.

---

## Audit Output Rule

A first-pass BYDA audit should preserve at least:

- audit type
- target entity
- result
- summary
- generated gaps
- enough basis to explain what was checked and why the result was produced

The first pass does not need a giant reasoning transcript.
But it must preserve enough basis to justify the outcome.

---

## Relationship to Readiness

BYDA does not replace readiness.
It strengthens and constrains readiness.

Readiness asks whether something may move forward.
BYDA asks what was checked, what failed, what became ambiguous, what drift exists, and whether the basis still deserves confidence.

The coupling rules live primarily in:

- `docs/architecture/core/readiness-evaluation-rules.md`

---

## Hammer Expectations

The hammer suite should verify at least:

- invalid audit requests fail deterministically
- hard-failure conditions produce `fail`
- non-blocking conditions can produce `warning`
- gap creation is consistent
- cross-artifact contradictions are detected
- ambiguity detection behaves deterministically for governed patterns
- staleness triggers invalidate prior confidence correctly

---

## Deferred Enhancements

The following remain intentionally deferred from the first-pass BYDA core:

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

These should be promoted only when real use shows the first-pass core is still too weak.

---

## Final Rule

The first-pass BYDA core should ask the right project questions, expose real gaps, catch contradictions and ambiguity, and invalidate stale confidence honestly.

That is enough to make BYDA worth using without turning it into an oversized system immediately.


