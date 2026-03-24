# GitHub Integration

## Purpose

This document defines the bounded integration between Project V and GitHub.

It exists to answer:

```text
How should Project V use GitHub for implementation traceability and audit support without making GitHub the owner of planning truth or making Project V a clone of GitHub?
```

Read this with:

- `docs/architecture/core/implementation-traceability.md`
- `docs/architecture/data/github-linkage-model.md`
- `docs/architecture/data/code-linkage-and-code-visibility.md`
- `docs/architecture/core/byda-in-project-v.md`
- `docs/architecture/core/audit-evaluation-rules.md`
- `docs/api/github-links-api.md`

---

## Core Rule

GitHub is an integration surface and evidence source for Project V.

GitHub is not the canonical owner of Project V planning truth.
Project V is not the canonical owner of GitHub truth.

---

## What Project V May Do

Project V may:

- link repos, branches, PRs, commits, and issues to project-scoped planning records
- use GitHub linkage to support implementation traceability
- use GitHub-linked evidence in BYDA-style `code_alignment` audit and drift checks
- surface implementation progression signals back into Project V's planning-side view

---

## What Project V Must Not Do

Project V must not:

- become the canonical owner of source-control history
- copy GitHub wholesale into its own database
- treat GitHub activity as a substitute for planning records
- let repo activity silently rewrite Project V planning truth

---

## Relationship to Implementation Traceability

GitHub should help Project V answer:

- what implementation package is linked to what repo?
- what PR or branch is associated with current work?
- what code evidence supports the implementation state?
- are there drift indicators between governed intent and code-linked reality?

---

## Link Validation Posture

Project V validates GitHub link format at the application layer but does not validate external
existence.

First-pass rules:

- `url` must be non-empty and must begin with `https://`; values that fail this check must
  fail with `400 Bad Request`
- `linkType` must use the governed controlled vocabulary (`repository`, `branch`,
  `pull_request`, `commit`, `issue`); invalid values must fail with `422 Unprocessable Entity`
- `externalId`, where supplied, is stored as-is; Project V does not validate it against GitHub
- Project V does not make outbound calls to resolve, verify, or validate a GitHub URL at
  creation or mutation time; this preserves boundary integrity

This posture is defined in full in `docs/api/api-conventions.md` under the
External Reference Validation Rule.

---

## Stale and Deleted Reference Posture

Project V does not automatically detect when a linked GitHub resource is deleted, renamed,
or moved.

First-pass posture:

- a stale or deleted GitHub reference does not automatically invalidate a `GitHubLink` record
- the calling operator or workflow is responsible for updating or retiring records where
  linked resources have changed
- a `code_alignment` audit that depends on GitHub-linked evidence may produce `fail` or
  `warning` if the linked evidence appears incomplete or inconsistent; the audit does not
  make outbound calls to verify liveness of linked URLs
- if a `GitHubLink` record is updated after a `code_alignment` audit was run against it,
  the prior audit may become `stale` as defined in `docs/architecture/core/audit-evaluation-rules.md`

---

## Multiple Links Per Record

A single Project V planning record may carry more than one GitHub link.

Expected patterns:

- a work item may link both a branch and a pull request once the PR is opened
- a work item may link a repository link as a standing traceability reference plus a specific
  commit or PR as implementation evidence
- a handoff may carry a PR link as part of its readiness basis

Multiple links of the same `linkType` to the same source entity and the same URL are rejected
as duplicates (`409 Conflict`). Multiple links of the same `linkType` to different URLs are
allowed and are treated as distinct traceability records.

There is no first-pass maximum link count per entity. If a cap is later needed, it must be
modeled explicitly through governance.

---

## Relationship to Code-Alignment Audit

`code_alignment` audit uses GitHub-linked evidence as its primary input in Project V.

Required posture:

- a `code_alignment` audit should fail if required GitHub linkage is missing for the target
  work where linkage is expected
- linked code evidence must be compared against governed intent; material drift produces
  `fail`; minor or incomplete coverage may produce `warning`
- if GitHub linkage changes materially after a `code_alignment` audit result is recorded,
  the prior result should be marked `stale`
- a `code_alignment` audit result of `pass` or `warning` that later becomes `stale` must
  force re-audit before implementation-tracking confidence is treated as current

The full `code_alignment` audit rules live in:

- `docs/architecture/core/audit-evaluation-rules.md`

---

## Project Scope Rule

GitHub linkage records in Project V must stay project-scoped from Project V's side.

- a repo may be linked by multiple Project V projects independently; each project owns its
  own `GitHubLink` records for that repo; there is no shared linkage across projects
- `sourceEntityId` must belong to the same project as the `GitHubLink` record
- reading a `GitHubLink` by ID alone must not bypass project ownership checks
- cross-project linkage leakage is forbidden

---

## Identity Mapping Posture

Project V does not maintain a Project V ↔ GitHub identity federation layer.

First-pass posture:

- Project V stores GitHub identifiers as explicit reference values: `url` is required;
  `externalId` and `label` are optional supplementary fields
- the caller is responsible for supplying a GitHub URL and optional identifier that is
  correct and belongs to the right repo and project context
- Project V does not validate that a GitHub URL resolves or that the linked resource
  belongs to the expected project; it stores the reference as given
- if a GitHub link is found to reference the wrong repo or a cross-project resource during
  a `code_alignment` audit, the audit must flag it as a traceability gap

This posture is minimal and explicit. It does not require a global identity mapping service.

---

## Auth and Credential Boundary Posture

This section defines the first-pass policy posture for how Project V should interact with
GitHub from a credential and access perspective.

### Least privilege

Any credential or token used by Project V to read from GitHub should be scoped to the
minimum required for the planned integration behavior.

For the first pass, Project V does not make outbound calls to GitHub. GitHub linkage is
stored as explicit URL and identifier references only; no outbound resolution is performed.

If a future capability requires Project V to query GitHub APIs (for example, to validate
linkage or retrieve code context for audit), that integration must be designed explicitly
as a bounded read-only surface. Write access to GitHub from Project V is out of scope.

### Read vs write

Project V's first-pass GitHub integration is storage-only from a credential perspective:
Project V stores GitHub references without making outbound calls.

If a future outbound read capability is added, it must use read-only credentials scoped
to the relevant repos only.

Project V must never hold credentials that allow it to write to GitHub repositories,
create issues, merge PRs, or trigger workflows on behalf of a project.

### Credential ownership

Any future GitHub-facing credentials used by Project V belong to Project V as a consumer.

Those credentials must not be shared with VEDA or V Forge.

This posture is policy-level. It does not prescribe secret management tooling or deployment
topology.

---

## Final Rule

GitHub should strengthen Project V traceability and audit posture.
It must not become the hidden brain of Project V.
