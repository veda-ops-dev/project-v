# Artifact Manifest Model

## Purpose

This document defines how Project V should model declared artifacts for planning, audit, and BYDA-style checks.

It exists to answer:

```text
How does Project V know what kinds of artifacts a project or implementation package is supposed to have so audit and drift logic can stay explicit and artifact-aware?
```

---

## Core Rule

Project V should not assume every project has the same artifact set.

Instead, Project V should model declared artifacts explicitly.

This allows audit logic to ask:

- what artifacts are expected?
- which artifacts exist?
- which artifacts were checked?
- which artifacts are missing?

---

## First-Pass Concepts

### Artifact Manifest

A governed declaration of the artifact types expected for a project, initiative, work item, or implementation package.

### Artifact Declaration

A specific declared artifact within the manifest.

### Artifact Type

A controlled classification such as:

- schema
- api_contract
- validation_contract
- config
- workflow_doc
- migration
- test_surface
- github_linkage
- implementation_package

The exact set should be governed later through controlled vocabularies if adopted.

---

## Current Decision

Artifact manifests are **deferred from first-pass schema**.

This model remains directional until Project V explicitly promotes artifact manifests into schema authority and API contracts.

## Why This Matters

Without an explicit artifact model:

- BYDA becomes vague
- readiness checks become inconsistent
- drift detection becomes hard to classify
- different project shapes get forced into one fake template

---

## Relationship to Audit

Audit logic should be able to evaluate:

- whether required artifacts were declared
- whether required artifacts are present
- whether the declared artifacts match the lifecycle phase
- whether the implementation-linked artifacts still match the declared plan

---

## Final Rule

Project V should model expected artifacts explicitly enough that audit and drift logic can be artifact-aware rather than assumption-heavy.
