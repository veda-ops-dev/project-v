# GitHub Linkage Model

## Purpose

This document defines how Project V should model GitHub linkage for planning-side implementation traceability.

It exists to answer:

```text
What GitHub-related records should Project V track so implementation remains traceable without turning Project V into GitHub?
```

---

## Core Rule

GitHub linkage in Project V should be explicit, bounded, and traceability-focused.

The model should support planning and governance needs without copying GitHub wholesale.

---

## First-Pass Concepts

The preferred first-pass shape is a **single `GitHubLink` table** with a governed `linkType` discriminator rather than five separate tables.

Recommended `linkType` values include:

- `repository`
- `branch`
- `pull_request`
- `commit`
- `issue`

This keeps the model explicit without over-modeling GitHub.

## Relationship to Project Scope

All GitHub linkage records must stay project-scoped from Project V's side.

A repo may exist independently of Project V, but the linkage record that says:

- this project
- this implementation package
- this PR

belongs in Project V as bounded traceability truth.

Intentional per-project duplication is acceptable here.
If two different Project V projects both link the same repository, each project should still own its own traceability record rather than relying on hidden shared linkage.

---

## Final Rule

Project V should model GitHub linkage only as much as needed to preserve implementation traceability and audit visibility.

No more.
