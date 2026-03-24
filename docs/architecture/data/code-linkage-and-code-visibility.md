# Code Linkage and Code Visibility

## Purpose

This document defines how Project V should handle code linkage, code-change tracking, and LLM-visible code context without turning the database into a second source-control system.

It exists to answer:

```text
Should Project V store project code files, should it track raw code changes itself, and what code-related truth belongs in Project V versus GitHub or the local repo?
```

Read this with:

- `docs/architecture/core/implementation-traceability.md`
- `docs/architecture/integrations/github-integration.md`
- `docs/architecture/data/github-linkage-model.md`
- `docs/architecture/core/byda-in-project-v.md`
- `docs/architecture/data/artifact-manifest-model.md`

---

## Core Rule

Project V should **not** store the full project codebase as canonical database truth.

Project V should **not** become the canonical owner of raw code-change history.

Project V **should** store bounded code linkage, implementation traceability, code-evidence records, and optional derived code-visibility records where that helps planning, audit, drift detection, and LLM-assisted reasoning.

---

## Canonical Ownership Split

### GitHub or local repo owns

These remain outside Project V as canonical truth:

- full source files
- commit history
- raw diffs
- branches
- pull requests
- merge history
- review history
- issue history

### Project V owns

These belong in Project V as planning-side or governance-side truth:

- which repo is relevant to a project or implementation package
- which branch / PR / commit / issue is linked to that work
- what code evidence supports the current planning state
- whether governed implementation drift exists
- what code artifacts are relevant to audit or readiness
- what LLM-visible derived code summaries or observations are worth preserving

---

## What Project V Should Not Do

Project V should not:

- store the whole codebase as canonical DB rows
- duplicate Git history wholesale
- mirror every file revision into Postgres
- turn code-tracking into a hidden GitHub clone
- pretend DB-stored code snapshots are the canonical source of truth

That path creates stale copies, ownership confusion, and schema bloat.

---

## What Project V Should Track

A first-pass Project V posture should support records or bounded links such as:

- repository link
- branch link
- pull request link
- commit link
- issue link
- implementation package link
- drift finding
- code evidence link
- optional code summary or code observation

This allows Project V to answer questions like:

- what code change belongs to this work item?
- what PR or commit implements this package?
- what code evidence supports this audit result?
- what changed since the last governed review?
- is the implementation drifting from the governed plan?

---

## Raw Change Tracking Rule

Canonical raw code-change tracking should remain in GitHub or the local repo.

That means Project V should reference:

- commit SHA
- PR number or identifier
- branch name
- issue identifier
- optional changed file paths or summaries where explicitly useful

Project V should not try to own the entire diff history.

---

## LLM Visibility Rule

If Project V needs to make code visible to an LLM, prefer one of these bounded strategies:

### 1. Code linkage only

Store:

- repo
- branch
- commit SHA
- path
- artifact role

This gives the LLM a precise pointer to where the code lives.

### 2. Derived code summaries

Store bounded summaries such as:

- file summary
- symbol summary
- relevant changed-file summary
- governed code observation

These should be treated as derived, disposable support data rather than canonical source truth.

### 3. Selected evidence excerpts

Where a specific code excerpt matters for audit or drift review, store a bounded evidence reference or excerpt tied to a commit and path.

Do not generalize this into storing the whole repo.

---

## Code Evidence Principle

A code-related record in Project V should prove something useful, such as:

- this file or commit is evidence for the implementation package
- this PR is the governed implementation vehicle
- this change introduced drift against the governed artifact set
- this commit satisfied or failed a BYDA-style audit expectation

If a code record proves nothing and explains nothing, it probably does not belong in Project V.

---

## Suggested First-Pass Model Direction

Without finalizing schema prematurely, the most useful first-pass direction is likely:

- explicit GitHub linkage records
- optional code-evidence or code-artifact-link records
- drift findings tied to implementation packages or work items
- optional derived code summaries where they materially help planning or audit

This keeps the system useful without overreaching.

---

## Relationship to BYDA

BYDA-style audit and drift checks may need code-linked evidence.

Project V should support that by tracking:

- what code artifact was checked
- what commit or PR was checked
- what governed artifact or implementation package it mapped to
- what finding or gap resulted

That supports audit truth without making Project V the owner of code history.

---

## Relationship to GitHub

GitHub remains the canonical source of raw code-change truth.

Project V stores the bounded planning-side interpretation and linkage.

In simple terms:

- GitHub says **what changed**
- Project V says **why it matters, what it maps to, and whether it is acceptable**

---

## Final Rule

Project V should track code linkage and code meaning, not the whole codebase.

If a proposal would make Project V a second Git repository in disguise, the proposal is wrong.
