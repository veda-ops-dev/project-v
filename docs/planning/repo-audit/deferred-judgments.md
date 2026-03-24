# Deferred Judgments

## Purpose

This file records post-audit judgments that are **not high-priority immediate fixes**.

Use it to track:

- issues worth fixing later
- issues that must be triaged before deciding whether to fix them
- intentional gaps that should be revisited only if later work makes them active risks

Do **not** use this file for active P0 fixes that should be resolved immediately.

---

## Judgment Categories

### Must triage
A legitimate issue or possible issue that needs a focused authority review before deciding whether to fix it.

### Worth fixing later
A real consistency or clarity improvement, but not urgent because stronger authority already governs current behavior.

### Intentional / skip
A documented and acceptable first-pass choice that should not be changed unless later work reopens it.

---

## Current Deferred Judgments

## 1. EvidenceLink / ResearchDoc duplicate prevention

### Judgment
Must triage.

### Why
This is not just documentation cleanup.
It may require:

- schema constraint changes
- API conflict-behavior changes
- idempotency posture changes

That makes it a governance decision rather than a casual follow-up fix.

### Suggested future batch
Schema/API governance batch.

### Current posture
Do not auto-fix.
Review whether first-pass caller-responsibility is intentional and sufficient before changing schema or API behavior.

---

## 2. DecisionRecord `updatedAt` maintenance explicit callout

### Judgment
Worth fixing later.

### Why
Current docs are functionally aligned.
This is clarity tightening rather than a real contradiction.

### Suggested future batch
Schema doc polish / maintenance-rule consistency batch.

### Current posture
No immediate action required.

---

## 3. `storageLocator` PATCH validation note in `research-docs-api.md`

### Judgment
Worth fixing later.

### Why
This is family-level validation consistency, not a critical authority conflict.

### Suggested future batch
API family consistency batch.

### Current posture
Safe to defer until a broader API consistency pass.

---

## 4. Family docs explicitly naming `data` / `nextCursor` wrapper

### Judgment
Worth fixing later.

### Why
`docs/api/api-conventions.md` already governs the wrapper structure.
The family docs are not currently contradicting that authority.
This is alignment polish, not a blocking conflict.

### Suggested future batch
API response-shape consistency batch.

### Current posture
Safe to defer.

---

## 5. `endpoint-governance.md` first-pass family list vs actual API docs present

### Judgment
Must triage.

### Why
This may be either:

- harmless list drift, or
- a real active-vs-deferred surface mismatch

It should be reviewed before broader API cleanup continues.

### Suggested future batch
API surface inventory / deferred-surface consistency batch.

### Current posture
Review soon, but not as a P0 emergency.

---

## 6. DecisionRecord `actor` field naming ambiguity

### Judgment
Worth fixing later.

### Why
The field name `actor` is used for:
- `DecisionRecord.actor` → decision author (caller-supplied)
- `StatusHistory.actor` → transition executor (server-resolved)

This creates semantic ambiguity but not a functional conflict.

### Suggested future batch
API terminology / field-meaning clarification batch.

### Current posture
No immediate action required. Clarify only if confusion emerges in usage or implementation.

---

## 7. Proposal-to-canonical promotion boundary hammer coverage

### Judgment
Must triage.

### Why
This is a documented uncovered invariant in the hammer coverage map.
It must be covered before any surface that can promote a proposal into canonical truth is allowed to ship.

### Suggested future batch
Proposal/promotion surface governance batch or hammer coverage expansion batch.

### Current posture
Do not add speculative coverage now.
Revisit immediately when any proposal-to-canonical promotion surface becomes real.

---

## 8. `hammer-dependencies` named-module consistency in hammer plan

### Judgment
Worth fixing later.

### Why
The concurrency/race coverage references `hammer-dependencies`, but that module is not yet explicitly named in the hammer plan phases.
This creates a planning consistency gap, not an active authority conflict.

### Suggested future batch
Hammer-plan consistency / module inventory batch.

### Current posture
No immediate action required, but align it before detailed module build-out.

---

## 9. Handoff status transition reverse-path completeness

### Judgment
Must triage.

### Why
V Forge return-path semantics now define rejection and re-entry via status rollback (e.g. `handed_off → ready`), but it is not yet confirmed that these transitions are explicitly allowed in `status-transitions.md`.

If not defined there, lifecycle authority and integration behavior are inconsistent.

### Suggested future batch
Status-transition authority alignment batch.

### Current posture
Verify and align allowed transitions before implementing handoff rejection and re-entry behavior.

---

## 10. StatusHistory requirement coverage for core entity types

### Judgment
Must triage.

### Why
`controlled-vocabularies.md` includes `project`, `objective`, `initiative`, and `work_item` in the StatusHistory entity-type vocabulary, but `status-transitions.md` does not explicitly define which transitions for these entities require StatusHistory.

The general rule ("where required") exists, but is not concretely specified per entity type, creating inconsistency with the now-explicit handoff rules.

### Suggested future batch
Status-history requirement alignment batch.

### Current posture
Do not assume universal history requirement yet.
Define explicit per-entity transition history rules in a future pass.

---

## Usage Rule

When a Claude batch reports follow-on recommendations:

1. classify each item as `Must triage`, `Worth fixing later`, or `Intentional / skip`
2. record only non-immediate items here
3. do not let this file become a dumping ground for active fix work
4. when an item is resolved, either remove it or mark it as closed with a brief note
