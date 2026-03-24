# Implementation Traceability

## Purpose

This document defines how Project V should track implementation from the planning side.

It exists to answer:

```text
What implementation-related truth should Project V track, what should stay outside it, and how should specs, code, GitHub activity, and drift findings remain traceable?
```

---

## Core Rule

Project V should track implementation traceability as planning and governance truth.

Project V should not become the canonical owner of all code or source-control truth.

---

## What Project V Should Track

Project V should track bounded implementation-side records such as:

- implementation packages
- declared implementation target repos
- branch / PR / commit / issue links
- implementation status from the planning perspective
- code-alignment audit results
- drift findings between planned artifacts and implementation-linked artifacts

---

## What Project V Should Not Track As Canonical Truth

Project V should not become the canonical owner of:

- the full Git history
- CI/CD runtime history
- source code content as canonical storage
- editor-native draft state
- publishing or execution truth owned by V Forge

---

## Traceability Chain

A first-pass traceability chain in Project V should preserve linkage across:

- research
- decisions
- objectives / initiatives / work items
- implementation package
- GitHub links
- audit results
- drift findings

That chain helps answer:

- why are we implementing this?
- what package is being implemented?
- what code artifacts correspond to it?
- has the implementation drifted from the governed plan?

---

## Bounded Implementation Package Principle

Project V should not throw code linkage directly onto every record without structure.

A bounded `ImplementationPackage` or equivalent concept is preferable because it:

- groups the implementation scope
- records target system and repo intent
- supports audit and drift checks
- keeps implementation-side tracking inspectable

### Current decision

`ImplementationPackage` is **deferred from first-pass schema**.

Until it is explicitly promoted through schema governance, Project V should express implementation scope through existing planning records plus explicit GitHub linkage and audit records.

## GitHub Linkage Principle

GitHub linkage should be explicit.

Project V should be able to store bounded links such as:

- repository
- branch
- pull request
- commit
- issue

Those links support traceability.
They do not transfer canonical ownership of GitHub truth into Project V.

---

## Drift Visibility Principle

Project V should support planning-side drift visibility such as:

- missing required implementation links
- implementation-linked work connected to the wrong project or repo
- planned artifact set not matching implementation-linked evidence
- spec or contract changes without corresponding implementation alignment

### Current decision

`DriftFinding` is **deferred from first-pass schema**.

Until it is explicitly promoted, drift should be represented through audit gaps, readiness gaps, and governed summaries rather than an unguided extra table.

## Final Rule

Implementation traceability belongs in Project V because it helps preserve governed planning, audit, and drift visibility.

But Project V must stay a traceability and governance layer, not a source-control warehouse.
