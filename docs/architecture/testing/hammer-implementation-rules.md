# Hammer Implementation Rules

## Purpose

This document defines implementation rules for Project V hammer authoring.

It exists because the following failure modes have already occurred in Project V hammer work:

- PowerShell version mismatch (Windows PowerShell 5 assumptions in a pwsh repo)
- Unicode and character encoding corruption in `.ps1` files
- Brittle string and SQL construction causing silent failures
- Casual use of `-replace` without accounting for PowerShell regex behavior
- Test names claiming concurrent behavior for sequential work
- Work marked READY based on change reports rather than file reads and actual execution
- Execution drift between runner scripts and module scripts

This document must be read before editing any hammer-related file.

It does not replace `hammer-doctrine.md`, `hammer-plan.md`, or `hammer-coverage-map.md`.
It supplements them with authoring discipline and execution correctness rules.

---

## Prompt Usage Rule

Any prompt that edits hammer-related files must read the following before starting:

- `docs/architecture/testing/hammer-doctrine.md`
- `docs/architecture/testing/hammer-plan.md`
- `docs/architecture/testing/hammer-coverage-map.md`
- `docs/architecture/testing/hammer-implementation-rules.md`

Do not begin hammer edits without reading all four.

If a conflict exists between this doc and the doctrine or plan docs, name the conflict explicitly and resolve it before proceeding.

---

## 1. Execution Posture

Project V hammer uses **pwsh (PowerShell 7+) only**.

Do not write hammer scripts that depend on Windows PowerShell 5 behavior, syntax, or defaults.

Do not assume that `powershell.exe` and `pwsh.exe` are interchangeable. They are not.

Specific rules:

- All hammer `.ps1` files must be executable under `pwsh`
- Do not use Windows PowerShell 5-only features, aliases, or behaviors
- Do not write runner or module scripts that invoke `powershell.exe` by name
- If a script must be invoked by path, use `pwsh` explicitly
- Do not assume that a script that works in Windows PowerShell 5 is ready for the hammer suite

When in doubt, test under `pwsh`. Version assumptions are not documented in comments — they must be correct in the execution model itself.

---

## 2. Character and Encoding Rules

Hammer `.ps1` files must be ASCII-safe.

Do not use:

- box-drawing characters (e.g., `+--+`, `|`, `─`, `┼`)
- smart quotes (`"`, `"`, `'`, `'`)
- decorative Unicode separators or dividers
- any character that renders differently across terminals, editors, or tools
- non-breaking spaces or other invisible Unicode whitespace

Use plain ASCII alternatives:

- Use `=` or `-` for visual dividers if needed
- Use straight quotes only: `"` and `'`
- Use plain hyphens for separators

Encoding must not corrupt output, break string comparisons, or cause silent failures when stdout is piped or captured.

If a character looks fine in your editor and breaks in the runner or in a psql pipe, it is not allowed.

---

## 3. SQL Construction Rules

Prefer here-strings for multi-line SQL embedded in PowerShell scripts.

Do:

```powershell
$sql = @"
SELECT id, status
FROM "WorkItem"
WHERE "projectId" = '$projectId'
ORDER BY "createdAt" ASC
"@
```

Do not:

- build SQL through concatenated quoted strings across multiple lines
- escape quotes inside already-escaped quotes without a clear and documented reason
- use backslash-quoting inside PowerShell strings that will be passed to psql as shell arguments

For scalar reads via `psql`, prefer deterministic output modes when the result must be compared or captured:

- Use `-t` (tuples only) to suppress column headers
- Use `-A` (unaligned) to suppress padding
- Combine `-t -A` when a single scalar value is required

Do not parse psql output that includes column headers, padding, or trailing whitespace unless the script explicitly trims and validates what it captures.

Avoid constructing SQL by interpolating values that contain special characters without clear awareness of what psql and the shell will do with them.

---

## 4. Regex and Replacement Rules

PowerShell `-replace` uses **regex**, not literal string matching.

Do not write `-replace` as if it were a literal find-and-replace.

Characters that are regex metacharacters and must be escaped or handled carefully when used as the pattern argument:

- `.` matches any character
- `+` means one or more
- `?` means zero or one (or non-greedy qualifier)
- `*` means zero or more
- `(` `)` are grouping operators
- `[` `]` define character classes
- `^` anchors to start (or negates inside a class)
- `$` anchors to end
- `\` is the escape character
- `{` `}` are quantifier delimiters
- `|` is alternation

Rules:

- Do not write `-replace 'some.thing', 'other'` expecting it to match the literal string `some.thing`
- If the intent is literal string replacement, use `[regex]::Escape()` on the pattern, or use the `.Replace()` string method instead
- Always verify what the pattern actually matches before assuming it is correct
- Comment non-obvious patterns with an explanation of what the regex is doing

Prefer `.Replace()` for simple literal substitutions where regex is not needed.

---

## 5. Truthful Test Naming

Test names and comments must match what the test actually does.

Do not call a test concurrent unless it actually runs concurrent work. Two sequential requests that probe a uniqueness constraint are a sequential probe, not a concurrency test. Name it accordingly.

Do not describe database enforcement in stronger terms than what is actually enforced. If the constraint is application-layer, say so. If it is a database-level unique constraint, say so.

Rules:

- Use names that describe what the test does, not what you wish it did
- Do not use the word "concurrent" for sequential operations
- Do not claim a test verifies a DB constraint if it only verifies application behavior
- Do not write a passing test as proof of a property the test did not actually stress
- If a test is a first-pass approximation of a harder property, say so in a comment

The test name is a contract with the next person reading it. Do not make that contract false.

---

## 6. Cleanup Posture

Test-created data should be cleaned up when practical.

Cleanup rules:

- Cleanup must target only data created by the current run, identified by scope (e.g., a test-specific project key or prefix)
- Do not write cleanup that truncates tables globally or removes data outside the test's own scope
- Cleanup failure should warn but must not silently rewrite the test result unless cleanup is itself the behavior under test
- If cleanup is skipped for a reason, document the reason in the script
- Do not depend on cleanup from a previous run to produce a clean state — setup must be self-sufficient

Cleanup is not the primary concern of a hammer test. Correctness of the assertion is.
But cleanup that is too broad or too silent can corrupt other tests or mislead operators.

---

## 7. Output and Tally Rules

Hammer modules must produce output that is easy to classify.

### PASS / SKIP / FAIL tally

Every hammer module run must produce a final tally line in this format:

```
PASS: N  SKIP: N  FAIL: N
```

Where N is an integer count for each category.

This line must appear at the end of each module's output.
It must be machine-readable and must not be buried in verbose output.

### INFO handling

Informational output during a run is allowed.

INFO lines should:

- begin with `INFO:` or an equivalent clear prefix
- not be counted in the PASS/SKIP/FAIL tally
- not be used as a substitute for a PASS assertion

### Verbose vs summary

Verbose output (individual test steps) should appear before the tally.
The tally must always be the final substantive line of output.

Do not produce tally-like lines during the run that could be confused with the final tally.

---

## 8. Verification Rule

Do not mark hammer work READY based on a change report alone.

**READY requires all of the following:**

1. The actual file was read after the change was made
2. The script was executed and the run was observed
3. The observed output was checked against the expected tally format
4. No silent failures were present in the output

A change report describing what was modified is not verification.
A claim that a script "should now work" is not verification.
An LLM asserting that a fix is correct without having executed the script is not verification.

If execution is not possible in the current context, state that explicitly and mark the status NOT READY or READY WITH FOLLOW-UP, with the specific follow-up being: read the file and run the script.

Do not mark READY to close a task. Mark READY when the output has been observed and it is correct.

---

## 9. Runner and Module Script Consistency

Runner scripts and module scripts must stay synchronized.

Failure mode: a runner invokes a module using an argument, flag, or path that no longer matches how the module is written. The module silently behaves differently than expected.

Rules:

- When a module script's interface changes, update the runner that calls it in the same change
- Do not assume a runner is correct because it was correct when last edited
- When a module is added to the suite, verify that the coordinator or runner reflects the addition
- When a module is renamed or moved, find every invocation and update it
- Do not test a module in isolation and mark the coordinator as correct without verifying the coordinator invocation matches

Drift between runner and module is a correctness defect. Treat it as one.

---

## Authority Docs

These docs govern hammer direction, coverage, and scope. This doc governs authoring and execution discipline.

- `docs/architecture/testing/hammer-doctrine.md`
- `docs/architecture/testing/hammer-plan.md`
- `docs/architecture/testing/hammer-coverage-map.md`
- `docs/architecture/data/schema-governance.md`
- `docs/api/endpoint-governance.md`
