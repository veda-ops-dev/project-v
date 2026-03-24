# API Conventions

## Purpose

This document defines the common API conventions for Project V.

It exists to answer:

```text
What common rules should all Project V endpoints follow so the API remains explicit, deterministic, multi-project-safe, and resistant to drift?
```

---

## Core Rule

Project V APIs must expose bounded planning and orchestration truth clearly.

They must be:

- explicit
- deterministic
- scope-honest
- boring
- stable

If an API design makes ownership or project scope harder to understand, it is incorrect.

---

## Naming Rule

Endpoint families should be named after bounded domain concepts.

Examples:

- `projects`
- `objectives`
- `initiatives`
- `work-items`
- `dependencies`
- `decisions`
- `readiness`
- `research-docs`
- `handoffs`

Do not use vague family names like:

- `misc`
- `helpers`
- `actions`
- `manager`

---

## Scope Rule

Project-scoped routes must make project context explicit.

That means the contract must make it clear:

- whether the route is project-scoped
- how project scope is supplied
- how cross-project access is rejected

Mutation routes must not rely on hidden project inference.

---

## Read Rule

Read routes must:

- preserve project boundaries
- return deterministic ordering for list surfaces
- fail safely when scope is wrong or ambiguous
- avoid hidden side effects

Reading by identifier alone must not bypass project ownership rules.

---

## Write Rule

Write routes must:

- require explicit project context where project-scoped truth is involved
- represent explicit actions
- reject illegal state changes
- preserve transaction integrity where multiple writes are involved
- avoid hidden convenience mutation

A route that sounds read-only must not mutate state.

---

## Ordering Rule

All list-like responses must define deterministic ordering.

Ordering should include a stable tie-breaker where needed.
No endpoint may rely on implicit database ordering.

---

## Pagination Rule

First-pass list endpoints must use cursor pagination. Offset pagination is not allowed.

Required posture:

- `limit` — maximum number of records to return per page; must be a positive integer; a bounded maximum is enforced server-side
- `cursor` — opaque continuation token from the previous page; omit for the first page
- deterministic ordering that matches the cursor strategy

### Cursor format rule

The first-pass cursor must be a base64url-encoded opaque string that encodes the last seen ordered tuple needed for continuation.

For a route with ordering:

```text
updatedAt desc, id asc
```

the cursor encodes the last seen `updatedAt` and `id` values from the previous page.

Clients must treat cursor values as opaque. Decoding or constructing cursor values manually is not supported.

### Cursor behavior rule

- a cursor is valid only for the ordering defined by that route family
- a malformed cursor must fail with `400 Bad Request`
- a cursor from one route family must not be used with another route family
- a route must not mix offset and cursor behavior in the same contract
- `offset` and `page` query parameters are not allowed on list endpoints

### Response behavior rule

Every list response must include:

- `data` — the array of records for this page
- `nextCursor` — the cursor to use to fetch the next page; must be `null` (not omitted) when there are no more results

A `nextCursor` of `null` is the definitive signal that the caller has reached the end of results.

### No-pagination exception

If a list family is small enough to return all records in a single response without pagination, that must be explicitly declared in the family contract with a stated justification. The default is cursor pagination.

Do not leave pagination behavior hypothetical in contract docs.

---

## Validation Rule

Validation behavior must be explicit and reproducible.

Contracts should make clear:

- what input is required
- what failures block the request
- what error posture is expected
- what fields use controlled vocabulary

---

## Error Code Rule

Project V uses a two-level error distinction across all route families:

- `400 Bad Request` — structural malformation: missing required fields, wrong types, malformed identifiers, unknown query parameters, caller-supplied forbidden fields
- `422 Unprocessable Entity` — semantically invalid but well-formed input: controlled-vocabulary violations, lifecycle invalidity, same-project integrity failures, rule-package incompatibility

This distinction is not optional. All route families must apply it consistently. The phrase "if that distinction is adopted" must not appear in any API contract.

---

## Actor Rule

Where a route writes a `StatusHistory` row, the `actor` field is server-resolved from the authenticated request context. Callers must not supply `actor` in the request body. The server must produce a non-empty `actor` value as part of completing any transition that writes a history row.

---

## PATCH Body Unknown Fields Rule

Unknown fields in a PATCH request body must be rejected with `400 Bad Request`. Silent ignore of extra body fields is not allowed. This rule applies to all PATCH routes across all Project V families.

## Unknown Query Parameter Rule

All list endpoints must fail with `400 Bad Request` when an unrecognized query parameter is supplied.

Silent ignore of unknown parameters is not allowed. Operators and LLMs must be able to trust that a query with an unrecognized filter is rejected rather than quietly returning unfiltered results.

---

## Error Response Rule

Error responses should use one stable body shape across Project V route families.

Recommended first-pass shape:

- `error.code`
- `error.message`
- `error.details` optional structured data
- `error.requestId` optional correlation value if available

The same class of error should not return wildly different body shapes across route families.

---

## Response Shape Rule

Responses should prefer:

- stable field names
- explicit IDs
- explicit status fields
- explicit project references where helpful
- explicit derived vs canonical distinctions where relevant

Do not return vague payloads that require guesswork.

### List response envelope vs item fields

Family docs describe item-level fields under their "Response shape" sections. Those field lists describe the contents of the `data` array, not the full list response envelope. The `data` / `nextCursor` wrapper is governed by the Pagination Rule above and applies to all list responses. Family docs do not need to repeat the wrapper structure.

---

## External Reference Validation Rule

Project V accepts external references (URLs, storage locators, external identifiers) but does not validate external existence.

First-pass posture:

- **Project V does not make outbound calls to validate external references.** Checking whether a GitHub URL resolves, a VEDA observation exists, or a storage locator is reachable would turn Project V into an observatory client and violate its boundary invariants.
- **Format validation is required.** External references must conform to basic syntactic rules at the point of creation or mutation:
  - `url` fields on `GitHubLink`: must be non-empty and must begin with `https://`. Values that do not meet this requirement must fail with `400 Bad Request`.
  - `targetLocator` fields on `EvidenceLink`: must be non-empty. No URL format is enforced because evidence locators may reference non-URL document paths or identifiers. Callers are responsible for supplying meaningful values.
  - `storageLocator` on `ResearchDoc`: must be non-empty. No format enforcement in the first pass.
- **Staleness is the caller's responsibility.** Project V does not track whether an external reference has become stale, moved, or been deleted. If an external reference becomes invalid after creation, the caller is responsible for updating or annotating the record.
- **Duplicate external references**: see the Idempotency Posture Rule for deduplication behavior per family.

This posture preserves boundary integrity. Project V is a planning record of external references, not a cache or validator of external state.

---

## Boundary Honesty Rule

Project V APIs must not pretend to be VEDA or V Forge APIs.

If Project V references another bounded system, the contract must keep that boundary visible.

A referenced external identifier is not the same thing as owned external truth.

---

## Expansion Rule

New route families or major route changes require governance review.

Do not add a route just because a surface wants a one-off shortcut.
Prefer coherent families over scattered convenience endpoints.

---

## Idempotency Posture Rule

Project V POST endpoints do not provide idempotency guarantees beyond natural uniqueness constraints.

First-pass posture:

- **Entities with a caller-supplied `key`** (Project, Objective, Initiative, WorkItem): duplicate creation attempts with the same `key` within the same scope will fail with `409 Conflict`. The caller must treat a `409` response as a signal that the record already exists and retrieve it separately. This is natural key-uniqueness idempotency, not full idempotency.
- **Keyless entities** (Dependency, GitHubLink, EvidenceLink, Handoff, ResearchDoc): duplicate creation attempts are governed by their unique constraints where they exist. GitHubLink and Dependency have enforced unique constraints and return `409`. EvidenceLink and ResearchDoc do not have enforced deduplication; duplicate records may be created by repeated requests. Callers are responsible for avoiding duplicate submissions for these families.
- **Evaluation and gap creation** (ReadinessEvaluation): each creation is a distinct evaluation event and is not considered a duplicate even if the same entity is evaluated multiple times. No deduplication is applied.
- **Status transitions**: a status route called twice with the same `newStatus` against an already-transitioned record will fail with `422 Unprocessable Entity` (illegal lifecycle transition), not silently succeed.

Project V does not support idempotency keys, request deduplication tokens, or conditional PUT semantics in the first pass. If stronger idempotency is required, it must be modeled explicitly through governance.

---

## Transaction Boundary Rule

The following operation classes must execute atomically. A partial write for any of these is a correctness violation:

- **Status transition + StatusHistory write**: any `/status` route that produces a `StatusHistory` row must write the status change and the history row in the same transaction. The status must not change without the history row, and the history row must not exist without the corresponding status change.
- **Readiness evaluation creation**: creating a `ReadinessEvaluation` must atomically create all associated `ReadinessGap` records and, where the evaluated entity is a `WorkItem`, update `readinessState` — all in the same transaction.
- **DecisionRecord supersedence**: the `recorded -> superseded` transition must write the status update and the `StatusHistory` row in the same transaction.
- **Entity creation with validation**: creation of records that validate cross-entity ownership (e.g., Dependency, Handoff, Initiative with `objectiveId`, WorkItem with `initiativeId`) must resolve and validate all referenced entities before committing the new record. If validation fails, no partial record may be persisted.

Do not specify database engine implementation details in API contracts. State the atomicity requirement at the contract level and let implementation choose the correct mechanism.

---

## Hammer Rule

Important routes should not be considered hardened until hammer coverage verifies:

- scope enforcement
- validation behavior
- deterministic ordering
- negative-path rejection
- transaction correctness where relevant

---

## Final Rule

Project V APIs should feel like governed contracts, not improvised plumbing.

If a route becomes harder to classify, harder to test, or easier to sprawl, the route is wrong.
