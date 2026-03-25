# HAMMER MODULE: core-initiatives
# Purpose: verify Project V initiative API contract, project-scope enforcement,
#          parent objective validation, validation boundaries, deterministic
#          ordering, cursor continuation, and status transition rules
# Invariants:
#   - Initiatives are always project-scoped; no initiative route operates without project context
#   - Initiative creation requires valid key and title
#   - Server assigns status=proposed on creation; caller-supplied status rejected (400)
#   - Duplicate key rejected within same project (409)
#   - Same key allowed in different projects
#   - Invalid key format rejected (400)
#   - Empty title rejected (400)
#   - Invalid priority rejected (422)
#   - Invalid targetSystem rejected (422)
#   - Unknown fields in body/query are rejected (400)
#   - objectiveId must belong to the same project; wrong-project objectiveId rejected (422)
#   - Missing objectiveId UUID rejected (400 or 422 depending on contract)
#   - Archived objective rejected as parent (422)
#   - Malformed objectiveId rejected (400)
#   - Wrong-project GET behaves as 404 (no cross-project existence leakage)
#   - Missing initiative returns 404
#   - List ordering is deterministic (priority asc, updatedAt desc, id asc)
#   - Cursor continuation is correct with no overlap
#   - PATCH is bounded to allowed fields only
#   - updatedAt changes on mutation
#   - PATCH with wrong-project objectiveId rejected (422)
#   - PATCH with archived objectiveId rejected (422)
#   - Status transitions follow governed rules (422 for forbidden, 400 for missing reason)
#   - StatusHistory row is written atomically for every valid status transition
#   - Creation under archived project rejected (422)
# Assumes: Migration 001 applied; API server running on BASE_URL

param(
    [string]$BaseUrl = "http://127.0.0.1:3100",
    [string]$ConnectionString = "postgresql://project_v_app:projectv@localhost:5432/project_v_local"
)

Write-Host "Running hammer: core-initiatives"
Write-Host ""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Invoke-Api($Method, $Path, $Body = $null) {
    $uri = "$BaseUrl$Path"
    try {
        if ($Body) {
            $json = $Body | ConvertTo-Json -Depth 5
            $resp = Invoke-WebRequest -Method $Method -Uri $uri `
                -ContentType 'application/json' -Body $json `
                -ErrorAction SilentlyContinue
        } else {
            $resp = Invoke-WebRequest -Method $Method -Uri $uri `
                -ErrorAction SilentlyContinue
        }
        return @{
            Status  = [int]$resp.StatusCode
            Body    = $resp.Content | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue
            Raw     = $resp.Content
        }
    } catch {
        $sc = 0
        if ($_.Exception.Response) { $sc = [int]$_.Exception.Response.StatusCode }
        $raw = ""
        try { $raw = $_.ErrorDetails.Message } catch {}
        $parsed = $null
        try { $parsed = $raw | ConvertFrom-Json -AsHashtable } catch {}
        return @{ Status = $sc; Body = $parsed; Raw = $raw }
    }
}

$passCount = 0
$skipCount = 0
$failCount = 0

function Record-Pass($label) { Write-Host "  PASS: $label"; $script:passCount++ }
function Record-Skip($label) { Write-Host "  SKIP: $label"; $script:skipCount++ }
function Record-Fail($label, $detail = "") {
    Write-Host "  FAIL: $label"
    if ($detail) { Write-Host "        $detail" }
    $script:failCount++
}

# ---------------------------------------------------------------------------
# Preflight: confirm API is reachable
# ---------------------------------------------------------------------------
Write-Host "  Preflight: checking API health..."
$health = Invoke-Api "GET" "/health"
if ($health.Status -ne 200) {
    Write-Host ""
    Write-Host "FAIL: API not reachable at $BaseUrl (status=$($health.Status))"
    Write-Host "      Start the server before running this hammer module."
    Write-Host ""
    exit 1
}
Write-Host "  API reachable."
Write-Host ""

# Per-run suffix to avoid key collisions on repeated runs.
$runSuffix = ([guid]::NewGuid().ToString()).Substring(0,8)

# ---------------------------------------------------------------------------
# Setup: create two projects and objectives for scope/parent tests
# ---------------------------------------------------------------------------
Write-Host "[setup] Creating test projects and objectives..."

$projKeyA = "hci-proja-$runSuffix"
$projKeyB = "hci-projb-$runSuffix"
$projA = Invoke-Api "POST" "/api/projects" @{ key = $projKeyA; name = "Initiative Hammer Project A" }
$projB = Invoke-Api "POST" "/api/projects" @{ key = $projKeyB; name = "Initiative Hammer Project B" }
$projAId = $projA.Body?.id
$projBId = $projB.Body?.id

if (-not $projAId -or -not $projBId) {
    Write-Host ""
    Write-Host "FAIL: Could not create test projects. Cannot continue."
    Write-Host "  Project A: status=$($projA.Status)"
    Write-Host "  Project B: status=$($projB.Status)"
    Write-Host ""
    Write-Host "PASS: $passCount | SKIP: $skipCount | FAIL: 1"
    exit 1
}
Write-Host "  Project A: $projAId"
Write-Host "  Project B: $projBId"

# Objective in project A (active, for valid parent linkage)
$objKeyA = "hci-obja-$runSuffix"
$objA = Invoke-Api "POST" "/api/projects/$projAId/objectives" @{
    key = $objKeyA; title = "Objective A for Initiative Tests"
}
$objAId = $objA.Body?.id

# Objective in project B (for cross-project parent tests)
$objKeyB = "hci-objb-$runSuffix"
$objB = Invoke-Api "POST" "/api/projects/$projBId/objectives" @{
    key = $objKeyB; title = "Objective B in Different Project"
}
$objBId = $objB.Body?.id

# Objective in project A that will be archived (for archived-parent tests)
$objKeyArc = "hci-objarc-$runSuffix"
$objArc = Invoke-Api "POST" "/api/projects/$projAId/objectives" @{
    key = $objKeyArc; title = "Objective to Archive"
}
$objArcId = $objArc.Body?.id

if ($objArcId) {
    # Archive it: proposed -> archived (requires reason)
    $arcResult = Invoke-Api "POST" "/api/projects/$projAId/objectives/$objArcId/status" @{
        newStatus = "archived"
        reason    = "hammer test: archiving for parent rejection test"
    }
    if ($arcResult.Status -ne 200) {
        Write-Host "  WARNING: Could not archive objective $objArcId (status=$($arcResult.Status)). Archived-parent tests may skip."
    }
}

if (-not $objAId -or -not $objBId) {
    Write-Host "  WARNING: Some objectives could not be created. Parent tests may skip."
}

Write-Host "  Objective A (proj A): $objAId"
Write-Host "  Objective B (proj B): $objBId"
Write-Host "  Objective Arc (proj A, archived): $objArcId"
Write-Host ""

# ---------------------------------------------------------------------------
# CASE 1: Create a valid initiative -- response shape, status, id present
# ---------------------------------------------------------------------------
Write-Host "[1] Create valid initiative"

$initKey1 = "hci-init1-$runSuffix"
$resp1 = Invoke-Api "POST" "/api/projects/$projAId/initiatives" @{
    key         = $initKey1
    title       = "Hammer Initiative Test 1"
    objectiveId = $objAId
    priority    = 25
    targetSystem = "veda"
}
$init1Id = $resp1.Body?.id

if ($resp1.Status -eq 201 -and $init1Id) {
    Record-Pass "POST returns 201 with id"
} else {
    Record-Fail "POST failed" "status=$($resp1.Status) body=$($resp1.Raw)"
}

if ($resp1.Body?.key -eq $initKey1) {
    Record-Pass "Response key matches submitted key"
} else {
    Record-Fail "Response key mismatch" "expected=$initKey1 got=$($resp1.Body?.key)"
}

if ($resp1.Body?.status -eq 'proposed') {
    Record-Pass "Server assigns status=proposed on creation"
} else {
    Record-Fail "status is not proposed on creation" "got=$($resp1.Body?.status)"
}

if ($resp1.Body?.projectId -eq $projAId) {
    Record-Pass "Response projectId matches path"
} else {
    Record-Fail "projectId mismatch" "expected=$projAId got=$($resp1.Body?.projectId)"
}

if ($resp1.Body?.objectiveId -eq $objAId) {
    Record-Pass "Response objectiveId matches submitted value"
} else {
    Record-Fail "objectiveId mismatch" "expected=$objAId got=$($resp1.Body?.objectiveId)"
}

if ($resp1.Body?.priority -eq 25) {
    Record-Pass "Priority matches submitted value (25)"
} else {
    Record-Fail "Priority mismatch" "expected=25 got=$($resp1.Body?.priority)"
}

if ($resp1.Body?.targetSystem -eq 'veda') {
    Record-Pass "targetSystem matches submitted value"
} else {
    Record-Fail "targetSystem mismatch" "expected=veda got=$($resp1.Body?.targetSystem)"
}

foreach ($field in @('id','projectId','objectiveId','key','title','status','priority','targetSystem','createdAt','updatedAt')) {
    if ($null -ne $resp1.Body?.($field)) {
        Record-Pass "Response includes field: $field"
    } else {
        Record-Fail "Response missing field: $field"
    }
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 1b: Create initiative without objectiveId (objectiveId is optional)
# ---------------------------------------------------------------------------
Write-Host "[1b] Create initiative without objectiveId (optional parent)"

$initKeyNoObj = "hci-noobj-$runSuffix"
$resp1b = Invoke-Api "POST" "/api/projects/$projAId/initiatives" @{
    key   = $initKeyNoObj
    title = "Initiative Without Objective"
}

if ($resp1b.Status -eq 201 -and $resp1b.Body?.id) {
    Record-Pass "Initiative created without objectiveId (201)"
} else {
    Record-Fail "Initiative without objectiveId failed" "status=$($resp1b.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 1c: Create initiative with default priority
# ---------------------------------------------------------------------------
Write-Host "[1c] Default priority is 100 when not supplied"

$initKeyDefPri = "hci-defpri-$runSuffix"
$resp1c = Invoke-Api "POST" "/api/projects/$projAId/initiatives" @{
    key   = $initKeyDefPri
    title = "Default Priority Test"
}

if ($resp1c.Status -eq 201 -and $resp1c.Body?.priority -eq 100) {
    Record-Pass "Default priority is 100"
} else {
    Record-Fail "Default priority mismatch" "got=$($resp1c.Body?.priority)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 2: Invalid key formats rejected (400)
# ---------------------------------------------------------------------------
Write-Host "[2] Invalid key format rejection"

$badKeys = @(
    @{ key = "HAS-UPPER"; title = "Bad" },
    @{ key = "has spaces"; title = "Bad" },
    @{ key = "-leadhyphen"; title = "Bad" },
    @{ key = "ab"; title = "Bad (too short)" },
    @{ key = ""; title = "Bad (empty)" }
)

foreach ($payload in $badKeys) {
    $r = Invoke-Api "POST" "/api/projects/$projAId/initiatives" $payload
    if ($r.Status -eq 400) {
        Record-Pass "Invalid key '$($payload.key)' rejected with 400"
    } else {
        Record-Fail "Invalid key '$($payload.key)' not rejected" "got status=$($r.Status)"
    }
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 3: Empty title rejected (400)
# ---------------------------------------------------------------------------
Write-Host "[3] Empty title rejection"

$r3 = Invoke-Api "POST" "/api/projects/$projAId/initiatives" @{
    key = "hci-notitle-$runSuffix"; title = ""
}
if ($r3.Status -eq 400) {
    Record-Pass "Empty title rejected with 400"
} else {
    Record-Fail "Empty title not rejected" "got status=$($r3.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 4: Invalid priority rejected (422)
# ---------------------------------------------------------------------------
Write-Host "[4] Invalid priority rejection"

$r4a = Invoke-Api "POST" "/api/projects/$projAId/initiatives" @{
    key = "hci-badpri1-$runSuffix"; title = "Bad Priority"; priority = 0
}
if ($r4a.Status -eq 422) {
    Record-Pass "Priority 0 rejected with 422"
} else {
    Record-Fail "Priority 0 not rejected" "got status=$($r4a.Status)"
}

$r4b = Invoke-Api "POST" "/api/projects/$projAId/initiatives" @{
    key = "hci-badpri2-$runSuffix"; title = "Bad Priority"; priority = 1001
}
if ($r4b.Status -eq 422) {
    Record-Pass "Priority 1001 rejected with 422"
} else {
    Record-Fail "Priority 1001 not rejected" "got status=$($r4b.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 4b: Invalid targetSystem rejected (422)
# ---------------------------------------------------------------------------
Write-Host "[4b] Invalid targetSystem rejection"

$r4c = Invoke-Api "POST" "/api/projects/$projAId/initiatives" @{
    key = "hci-badts-$runSuffix"; title = "Bad TargetSystem"; targetSystem = "banana"
}
if ($r4c.Status -eq 422) {
    Record-Pass "Invalid targetSystem 'banana' rejected with 422"
} else {
    Record-Fail "Invalid targetSystem not rejected" "got status=$($r4c.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 5: Unknown fields in POST body rejected (400)
# ---------------------------------------------------------------------------
Write-Host "[5] Unknown fields in POST body rejected"

$r5 = Invoke-Api "POST" "/api/projects/$projAId/initiatives" @{
    key = "hci-unkfld-$runSuffix"; title = "Unknown Field"; bogus = "value"
}
if ($r5.Status -eq 400) {
    Record-Pass "Unknown field in POST body rejected with 400"
} else {
    Record-Fail "Unknown field in POST body accepted" "got status=$($r5.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 6: Caller-supplied status on creation rejected (400)
# ---------------------------------------------------------------------------
Write-Host "[6] Caller-supplied status on creation rejected"

$r6 = Invoke-Api "POST" "/api/projects/$projAId/initiatives" @{
    key = "hci-withstat-$runSuffix"; title = "Status Test"; status = "active"
}
if ($r6.Status -eq 400) {
    Record-Pass "Caller-supplied status on creation rejected with 400"
} else {
    Record-Fail "Caller-supplied status accepted" "got status=$($r6.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 7: Unknown query parameters rejected (400)
# ---------------------------------------------------------------------------
Write-Host "[7] Unknown query parameter rejected"

$r7 = Invoke-Api "GET" "/api/projects/$projAId/initiatives?bogusparam=value"
if ($r7.Status -eq 400) {
    Record-Pass "Unknown query parameter rejected with 400"
} else {
    Record-Fail "Unknown query parameter not rejected" "got status=$($r7.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 8: Duplicate key rejected within same project (409)
# ---------------------------------------------------------------------------
Write-Host "[8] Duplicate key within same project rejected (409)"

if ($init1Id) {
    $r8 = Invoke-Api "POST" "/api/projects/$projAId/initiatives" @{
        key = $initKey1; title = "Duplicate Attempt"
    }
    if ($r8.Status -eq 409) {
        Record-Pass "Duplicate key within same project rejected with 409"
    } else {
        Record-Fail "Duplicate key not rejected" "got status=$($r8.Status)"
    }
} else {
    Record-Skip "Duplicate key test (initiative creation failed in case 1)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 9: Same key allowed in different project
# ---------------------------------------------------------------------------
Write-Host "[9] Same key allowed in different project"

$r9 = Invoke-Api "POST" "/api/projects/$projBId/initiatives" @{
    key = $initKey1; title = "Same Key Different Project"
}
if ($r9.Status -eq 201) {
    Record-Pass "Same key in different project accepted (201)"
} else {
    Record-Fail "Same key in different project rejected" "got status=$($r9.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 10: GET single initiative within correct project
# ---------------------------------------------------------------------------
Write-Host "[10] GET single initiative by id within correct project"

if ($init1Id) {
    $r10 = Invoke-Api "GET" "/api/projects/$projAId/initiatives/$init1Id"
    if ($r10.Status -eq 200 -and $r10.Body?.id -eq $init1Id) {
        Record-Pass "GET returns correct initiative record"
    } else {
        Record-Fail "GET failed" "status=$($r10.Status)"
    }
} else {
    Record-Skip "GET single initiative (creation failed)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 11: Wrong-project GET returns 404 (no cross-project leakage)
# ---------------------------------------------------------------------------
Write-Host "[11] Wrong-project GET returns 404"

if ($init1Id) {
    $r11 = Invoke-Api "GET" "/api/projects/$projBId/initiatives/$init1Id"
    if ($r11.Status -eq 404) {
        Record-Pass "Wrong-project GET returns 404 (no cross-project leakage)"
    } else {
        Record-Fail "Wrong-project GET did not return 404" "got status=$($r11.Status)"
    }
} else {
    Record-Skip "Wrong-project test (creation failed)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 12: Missing initiative returns 404
# ---------------------------------------------------------------------------
Write-Host "[12] Missing initiative returns 404"

$nonExistentId = [guid]::NewGuid().ToString()
$r12 = Invoke-Api "GET" "/api/projects/$projAId/initiatives/$nonExistentId"
if ($r12.Status -eq 404) {
    Record-Pass "Missing initiative returns 404"
} else {
    Record-Fail "Missing initiative did not return 404" "got status=$($r12.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 13: Malformed initiativeId returns 400
# ---------------------------------------------------------------------------
Write-Host "[13] Malformed initiativeId returns 400"

$r13 = Invoke-Api "GET" "/api/projects/$projAId/initiatives/not-a-uuid"
if ($r13.Status -eq 400) {
    Record-Pass "Malformed initiativeId returns 400"
} else {
    Record-Fail "Malformed initiativeId did not return 400" "got status=$($r13.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 14: PATCH allowed fields successfully; updatedAt changes
# ---------------------------------------------------------------------------
Write-Host "[14] PATCH allowed fields and updatedAt verification"

if ($init1Id) {
    $beforePatch = Invoke-Api "GET" "/api/projects/$projAId/initiatives/$init1Id"
    $oldUpdatedAt = $beforePatch.Body?.updatedAt

    Start-Sleep -Milliseconds 50

    $r14 = Invoke-Api "PATCH" "/api/projects/$projAId/initiatives/$init1Id" @{
        title       = "Updated Initiative Title"
        description = "Updated description"
        priority    = 50
        targetSystem = "v_forge"
    }
    if ($r14.Status -eq 200 -and $r14.Body?.title -eq "Updated Initiative Title") {
        Record-Pass "PATCH returns 200 with updated record"
    } else {
        Record-Fail "PATCH failed" "status=$($r14.Status) title=$($r14.Body?.title)"
    }

    if ($r14.Body?.priority -eq 50) {
        Record-Pass "PATCH updated priority correctly"
    } else {
        Record-Fail "Priority not updated" "got=$($r14.Body?.priority)"
    }

    if ($r14.Body?.targetSystem -eq 'v_forge') {
        Record-Pass "PATCH updated targetSystem correctly"
    } else {
        Record-Fail "targetSystem not updated" "got=$($r14.Body?.targetSystem)"
    }

    $newUpdatedAt = $r14.Body?.updatedAt
    if ($newUpdatedAt -and $oldUpdatedAt -and $newUpdatedAt -ne $oldUpdatedAt) {
        Record-Pass "updatedAt changed on mutation"
    } else {
        Record-Fail "updatedAt did not change on mutation" "old=$oldUpdatedAt new=$newUpdatedAt"
    }
} else {
    Record-Skip "PATCH test (creation failed)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 15: PATCH unknown field rejected (400)
# ---------------------------------------------------------------------------
Write-Host "[15] PATCH unknown field rejected"

if ($init1Id) {
    $r15 = Invoke-Api "PATCH" "/api/projects/$projAId/initiatives/$init1Id" @{
        title = "OK"; unknownField = "bad"
    }
    if ($r15.Status -eq 400) {
        Record-Pass "PATCH with unknown field rejected with 400"
    } else {
        Record-Fail "PATCH with unknown field not rejected" "got status=$($r15.Status)"
    }
} else {
    Record-Skip "PATCH unknown field test (creation failed)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 15b: PATCH forbidden fields rejected (400)
# ---------------------------------------------------------------------------
Write-Host "[15b] PATCH forbidden fields rejected (status, key, projectId, id)"

if ($init1Id) {
    foreach ($forbiddenField in @('status', 'key', 'projectId', 'id')) {
        $patchBody = @{ $forbiddenField = "hacked" }
        $r15b = Invoke-Api "PATCH" "/api/projects/$projAId/initiatives/$init1Id" $patchBody
        if ($r15b.Status -eq 400) {
            Record-Pass "PATCH with forbidden field '$forbiddenField' rejected with 400"
        } else {
            Record-Fail "PATCH with forbidden field '$forbiddenField' not rejected" "got status=$($r15b.Status)"
        }
    }
} else {
    Record-Skip "PATCH forbidden fields test (creation failed)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 16: Deterministic ordering and cursor continuation
# ---------------------------------------------------------------------------
Write-Host "[16] Deterministic ordering and cursor continuation"

$orderInits = @()
$orderPriorities = @(50, 10, 50, 10, 50)
for ($i = 1; $i -le 5; $i++) {
    $r = Invoke-Api "POST" "/api/projects/$projAId/initiatives" @{
        key      = "hci-ord-$i-$runSuffix"
        title    = "Order Test $i"
        priority = $orderPriorities[$i - 1]
    }
    if ($r.Status -eq 201 -and $r.Body?.id) {
        $orderInits += $r.Body
    }
    Start-Sleep -Milliseconds 50
}

# Project A now has several initiatives. Fetch with limit=3 to force pagination.
$r16a = Invoke-Api "GET" "/api/projects/$projAId/initiatives?limit=3"
if ($r16a.Status -eq 200) {
    $page1 = $r16a.Body?.data
    $nc    = $r16a.Body?.nextCursor

    if ($r16a.Body.ContainsKey('nextCursor')) {
        Record-Pass "List response includes nextCursor field"
    } else {
        Record-Fail "List response missing nextCursor field"
    }

    if ($page1 -and $page1.Count -le 3) {
        Record-Pass "List with limit=3 returns at most 3 records"
    } else {
        Record-Fail "List with limit=3 returned wrong count" "got=$($page1?.Count)"
    }

    # Verify ordering within page: priority asc, then updatedAt desc
    if ($page1 -and $page1.Count -ge 2) {
        $orderCorrect = $true
        for ($i = 0; $i -lt $page1.Count - 1; $i++) {
            $a = $page1[$i]
            $b = $page1[$i + 1]
            $priA = [int]$a.priority
            $priB = [int]$b.priority
            if ($priA -gt $priB) {
                $orderCorrect = $false
                break
            }
            if ($priA -eq $priB) {
                $tA = [datetime]$a.updatedAt
                $tB = [datetime]$b.updatedAt
                if ($tA -lt $tB) {
                    $orderCorrect = $false
                    break
                }
            }
        }
        if ($orderCorrect) {
            Record-Pass "Page 1 ordering is correct (priority asc, updatedAt desc)"
        } else {
            Record-Fail "Page 1 ordering is incorrect"
        }
    }

    # Cursor continuation
    if ($nc) {
        $encoded = [System.Uri]::EscapeDataString($nc)
        $r16b = Invoke-Api "GET" "/api/projects/$projAId/initiatives?limit=3&cursor=$encoded"
        if ($r16b.Status -eq 200) {
            Record-Pass "Cursor continuation returns 200"
            $page2 = $r16b.Body?.data

            # No overlap between pages
            $overlap = @()
            if ($page1 -and $page2) {
                $ids1 = $page1 | ForEach-Object { $_.id }
                $ids2 = $page2 | ForEach-Object { $_.id }
                $overlap = $ids1 | Where-Object { $ids2 -contains $_ }
            }
            if ($overlap.Count -eq 0) {
                Record-Pass "No overlap between page 1 and page 2"
            } else {
                Record-Fail "Pages contain duplicate ids" "overlap=$($overlap -join ',')"
            }

            # Verify page 2 ordering
            if ($page2 -and $page2.Count -ge 2) {
                $p2OrderCorrect = $true
                for ($i = 0; $i -lt $page2.Count - 1; $i++) {
                    $a = $page2[$i]
                    $b = $page2[$i + 1]
                    $priA = [int]$a.priority
                    $priB = [int]$b.priority
                    if ($priA -gt $priB) {
                        $p2OrderCorrect = $false
                        break
                    }
                    if ($priA -eq $priB) {
                        $tA = [datetime]$a.updatedAt
                        $tB = [datetime]$b.updatedAt
                        if ($tA -lt $tB) {
                            $p2OrderCorrect = $false
                            break
                        }
                    }
                }
                if ($p2OrderCorrect) {
                    Record-Pass "Page 2 ordering is correct"
                } else {
                    Record-Fail "Page 2 ordering is incorrect"
                }
            }

            # Cross-page ordering: last item of page 1 must precede first item of page 2
            if ($page1 -and $page1.Count -gt 0 -and $page2 -and $page2.Count -gt 0) {
                $lastP1  = $page1[$page1.Count - 1]
                $firstP2 = $page2[0]
                $priLast  = [int]$lastP1.priority
                $priFirst = [int]$firstP2.priority
                $crossOk = $false
                if ($priLast -lt $priFirst) {
                    $crossOk = $true
                } elseif ($priLast -eq $priFirst) {
                    $tLast  = [datetime]$lastP1.updatedAt
                    $tFirst = [datetime]$firstP2.updatedAt
                    if ($tLast -gt $tFirst) {
                        $crossOk = $true
                    } elseif ($tLast -eq $tFirst) {
                        $crossOk = $lastP1.id -lt $firstP2.id
                    }
                }
                if ($crossOk) {
                    Record-Pass "Cross-page ordering is continuous"
                } else {
                    Record-Fail "Cross-page ordering gap detected"
                }
            }
        } else {
            Record-Fail "Cursor continuation request failed" "status=$($r16b.Status)"
        }
    } else {
        Record-Skip "Cursor continuation (all results fit in one page)"
    }
} else {
    Record-Fail "GET initiatives list failed" "status=$($r16a.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 17: Malformed cursor rejected (400)
# ---------------------------------------------------------------------------
Write-Host "[17] Malformed cursor rejection"

$r17 = Invoke-Api "GET" "/api/projects/$projAId/initiatives?cursor=not-a-real-cursor"
if ($r17.Status -eq 400) {
    Record-Pass "Malformed cursor rejected with 400"
} else {
    Record-Fail "Malformed cursor not rejected" "got status=$($r17.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 18: Status transition -- valid (proposed -> active)
# ---------------------------------------------------------------------------
Write-Host "[18] Status transition: proposed -> active (valid, no reason required)"

if ($init1Id) {
    $r18 = Invoke-Api "POST" "/api/projects/$projAId/initiatives/$init1Id/status" @{
        newStatus = "active"
    }
    if ($r18.Status -eq 200 -and $r18.Body?.status -eq 'active') {
        Record-Pass "proposed -> active transition succeeds"
    } else {
        Record-Fail "proposed -> active transition failed" "status=$($r18.Status) body=$($r18.Raw)"
    }
    if ($r18.Body?.statusHistoryId) {
        Record-Pass "Response includes statusHistoryId"
    } else {
        Record-Fail "Response missing statusHistoryId"
    }
} else {
    Record-Skip "Status transition test (creation failed)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 19: StatusHistory row written atomically -- verify via DB
# ---------------------------------------------------------------------------
Write-Host "[19] StatusHistory row exists for transition (DB check)"

if ($init1Id) {
    $c19Sql = @"
SELECT COUNT(*)::int FROM app.status_history WHERE "entityId" = '$init1Id'::uuid AND "entityType" = 'initiative';
"@
    $tmpFile19 = [System.IO.Path]::GetTempFileName() + ".sql"
    [System.IO.File]::WriteAllText($tmpFile19, $c19Sql, [System.Text.Encoding]::UTF8)
    try {
        $c19Out  = psql $ConnectionString -t -A --file $tmpFile19 2>&1
        $c19Exit = $LASTEXITCODE
    } finally {
        Remove-Item -Force -ErrorAction SilentlyContinue $tmpFile19
    }

    if ($c19Exit -ne 0 -or ($c19Out -join "") -match 'ERROR') {
        Record-Fail "DB query for StatusHistory failed" ($c19Out -join " ")
    } else {
        $cntStr = ($c19Out | Where-Object { $_.Trim() -ne "" } | Select-Object -First 1).Trim()
        $cntVal = 0
        if ([int]::TryParse($cntStr, [ref]$cntVal) -and $cntVal -ge 1) {
            Record-Pass "StatusHistory row exists for initiative transition (count=$cntVal)"
        } else {
            Record-Fail "No StatusHistory row found for initiative transition (raw='$cntStr')"
        }
    }
} else {
    Record-Skip "StatusHistory DB check (creation failed)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 20: Forbidden transition rejected (422)
# (completed -> active is forbidden)
# ---------------------------------------------------------------------------
Write-Host "[20] Forbidden transition rejected (422)"

if ($init1Id) {
    # init1Id is now 'active'. Transition to completed, then try completed -> active.
    $r20a = Invoke-Api "POST" "/api/projects/$projAId/initiatives/$init1Id/status" @{
        newStatus = "completed"
    }
    if ($r20a.Status -eq 200) {
        $r20b = Invoke-Api "POST" "/api/projects/$projAId/initiatives/$init1Id/status" @{
            newStatus = "active"
        }
        if ($r20b.Status -eq 422) {
            Record-Pass "Forbidden transition (completed -> active) rejected with 422"
        } else {
            Record-Fail "Forbidden transition not rejected" "got status=$($r20b.Status)"
        }
    } else {
        Record-Skip "Forbidden transition test (active -> completed step failed: status=$($r20a.Status))"
    }
} else {
    Record-Skip "Forbidden transition test (creation failed)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 21: Missing reason rejected for required-reason transition (400)
# (proposed -> archived requires reason)
# ---------------------------------------------------------------------------
Write-Host "[21] Missing reason rejected for required-reason transition (400)"

$initKeyReason = "hci-noreason-$runSuffix"
$rReason = Invoke-Api "POST" "/api/projects/$projAId/initiatives" @{
    key = $initKeyReason; title = "Reason Test Initiative"
}
$initReasonId = $rReason.Body?.id

if ($initReasonId) {
    $r21 = Invoke-Api "POST" "/api/projects/$projAId/initiatives/$initReasonId/status" @{
        newStatus = "archived"
    }
    if ($r21.Status -eq 400) {
        Record-Pass "Missing reason for proposed -> archived rejected with 400"
    } else {
        Record-Fail "Missing reason not rejected" "got status=$($r21.Status)"
    }

    # With reason, the transition succeeds
    $r21b = Invoke-Api "POST" "/api/projects/$projAId/initiatives/$initReasonId/status" @{
        newStatus = "archived"
        reason    = "archiving for hammer test"
    }
    if ($r21b.Status -eq 200) {
        Record-Pass "proposed -> archived with reason succeeds"
    } else {
        Record-Fail "proposed -> archived with reason failed" "got status=$($r21b.Status)"
    }
} else {
    Record-Skip "Missing reason test (initiative creation failed)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 22: Invalid newStatus value rejected (422)
# ---------------------------------------------------------------------------
Write-Host "[22] Invalid newStatus value rejected (422)"

$initKey22 = "hci-badstat-$runSuffix"
$r22create = Invoke-Api "POST" "/api/projects/$projAId/initiatives" @{
    key = $initKey22; title = "Invalid Status Test"
}
$init22Id = $r22create.Body?.id

if ($init22Id) {
    $r22 = Invoke-Api "POST" "/api/projects/$projAId/initiatives/$init22Id/status" @{
        newStatus = "banana"
    }
    if ($r22.Status -eq 422) {
        Record-Pass "Invalid newStatus value rejected with 422"
    } else {
        Record-Fail "Invalid newStatus not rejected" "got status=$($r22.Status)"
    }
} else {
    Record-Skip "Invalid newStatus test (creation failed)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 23: Archived -> active forbidden (422)
# ---------------------------------------------------------------------------
Write-Host "[23] Archived -> active forbidden (422)"

# initReasonId was archived in case 21
if ($initReasonId) {
    $r23 = Invoke-Api "POST" "/api/projects/$projAId/initiatives/$initReasonId/status" @{
        newStatus = "active"
    }
    if ($r23.Status -eq 422) {
        Record-Pass "archived -> active rejected with 422"
    } else {
        Record-Fail "archived -> active not rejected" "got status=$($r23.Status)"
    }
} else {
    Record-Skip "Archived -> active test (creation failed)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 24: Duplicate key sequential enforcement
# ---------------------------------------------------------------------------
Write-Host "[24] Duplicate key constraint enforcement (sequential duplicate requests)"

$key24 = "hci-seqdup-$runSuffix"
$body24 = @{ key = $key24; title = "Sequential Dup Test" }

$raceA = Invoke-Api "POST" "/api/projects/$projAId/initiatives" $body24
$raceB = Invoke-Api "POST" "/api/projects/$projAId/initiatives" $body24

$statusA = $raceA.Status
$statusB = $raceB.Status

$successCount = @($statusA, $statusB) | Where-Object { $_ -eq 201 } | Measure-Object | Select-Object -ExpandProperty Count
$conflictCount = @($statusA, $statusB) | Where-Object { $_ -eq 409 } | Measure-Object | Select-Object -ExpandProperty Count

if ($successCount -eq 1 -and $conflictCount -eq 1) {
    Record-Pass "Duplicate key constraint: exactly 1 success, 1 conflict"
} else {
    Record-Fail "Duplicate key constraint pattern wrong" "statuses=$statusA,$statusB"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 25: Creation under archived project rejected (422)
# ---------------------------------------------------------------------------
Write-Host "[25] Creation under archived project rejected (422)"

$projKeyArcProj = "hci-arcprj-$runSuffix"
$rArcProj = Invoke-Api "POST" "/api/projects" @{ key = $projKeyArcProj; name = "Archived Project for Init" }
$arcProjId = $rArcProj.Body?.id

if ($arcProjId) {
    $rArc = Invoke-Api "POST" "/api/projects/$arcProjId/status" @{
        newStatus = "archived"
        reason    = "archiving for hammer test"
    }
    if ($rArc.Status -eq 200) {
        $r25 = Invoke-Api "POST" "/api/projects/$arcProjId/initiatives" @{
            key = "hci-underarc-$runSuffix"; title = "Under Archived Project"
        }
        if ($r25.Status -eq 422) {
            Record-Pass "Creation under archived project rejected with 422"
        } else {
            Record-Fail "Creation under archived project not rejected" "got status=$($r25.Status)"
        }
    } else {
        Record-Skip "Archived project test (archive step failed: status=$($rArc.Status))"
    }
} else {
    Record-Skip "Archived project test (project creation failed)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 26: List response scoped to correct project only
# ---------------------------------------------------------------------------
Write-Host "[26] List response scoped to correct project"

$r26 = Invoke-Api "GET" "/api/projects/$projBId/initiatives"
if ($r26.Status -eq 200) {
    $data26 = $r26.Body?.data
    $leakedIds = @()
    if ($data26) {
        foreach ($item in $data26) {
            if ($item.projectId -ne $projBId) {
                $leakedIds += $item.id
            }
        }
    }
    if ($leakedIds.Count -eq 0) {
        Record-Pass "List response contains only initiatives from the requested project"
    } else {
        Record-Fail "List response contains cross-project initiatives" "leaked=$($leakedIds -join ',')"
    }
} else {
    Record-Fail "GET initiatives list for projB failed" "status=$($r26.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 27: StatusHistory reason persisted for required-reason transition (DB check)
# ---------------------------------------------------------------------------
Write-Host "[27] StatusHistory reason is persisted for required-reason transition (DB check)"

$initKey27 = "hci-reason27-$runSuffix"
$r27create = Invoke-Api "POST" "/api/projects/$projAId/initiatives" @{
    key = $initKey27; title = "Reason Persist Test"
}
$init27Id = $r27create.Body?.id

if ($init27Id) {
    # proposed -> blocked
    Invoke-Api "POST" "/api/projects/$projAId/initiatives/$init27Id/status" @{ newStatus = "blocked" } | Out-Null
    # blocked -> archived with reason
    $archiveReason = "hammer-test-archive-reason"
    $r27arc = Invoke-Api "POST" "/api/projects/$projAId/initiatives/$init27Id/status" @{
        newStatus = "archived"
        reason    = $archiveReason
    }

    if ($r27arc.Status -eq 200) {
        $c27Sql = @"
SELECT reason FROM app.status_history WHERE "entityId" = '$init27Id'::uuid AND "entityType" = 'initiative' AND "newStatus" = 'archived' LIMIT 1;
"@
        $tmpFile27 = [System.IO.Path]::GetTempFileName() + ".sql"
        [System.IO.File]::WriteAllText($tmpFile27, $c27Sql, [System.Text.Encoding]::UTF8)
        try {
            $c27Out  = psql $ConnectionString -t -A --file $tmpFile27 2>&1
            $c27Exit = $LASTEXITCODE
        } finally {
            Remove-Item -Force -ErrorAction SilentlyContinue $tmpFile27
        }

        if ($c27Exit -eq 0) {
            $reasonStr = ($c27Out | Where-Object { $_.Trim() -ne "" } | Select-Object -First 1).Trim()
            if ($reasonStr -eq $archiveReason) {
                Record-Pass "StatusHistory reason persisted correctly"
            } else {
                Record-Fail "StatusHistory reason mismatch" "expected='$archiveReason' got='$reasonStr'"
            }
        } else {
            Record-Fail "DB query for StatusHistory reason failed" ($c27Out -join " ")
        }
    } else {
        Record-Skip "Reason persistence test (blocked -> archived failed: status=$($r27arc.Status))"
    }
} else {
    Record-Skip "Reason persistence test (creation failed)"
}

Write-Host ""

# ===========================================================================
# PARENT OBJECTIVE VALIDATION (most important correctness area)
# ===========================================================================

# ---------------------------------------------------------------------------
# CASE 30: Create initiative with valid objectiveId in same project
# (Already verified in case 1. Explicit re-check for clarity.)
# ---------------------------------------------------------------------------
Write-Host "[30] Create initiative with valid same-project objectiveId"

if ($objAId) {
    $initKey30 = "hci-validobj-$runSuffix"
    $r30 = Invoke-Api "POST" "/api/projects/$projAId/initiatives" @{
        key         = $initKey30
        title       = "Valid Parent Objective"
        objectiveId = $objAId
    }
    if ($r30.Status -eq 201 -and $r30.Body?.objectiveId -eq $objAId) {
        Record-Pass "Initiative created with valid same-project objectiveId"
    } else {
        Record-Fail "Initiative with valid objectiveId failed" "status=$($r30.Status)"
    }
} else {
    Record-Skip "Valid objectiveId test (objective creation failed in setup)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 31: Create initiative with wrong-project objectiveId (must fail)
# This is the most critical parent-scope test.
# ---------------------------------------------------------------------------
Write-Host "[31] Create initiative with wrong-project objectiveId rejected"

if ($objBId) {
    $initKey31 = "hci-wrongobj-$runSuffix"
    $r31 = Invoke-Api "POST" "/api/projects/$projAId/initiatives" @{
        key         = $initKey31
        title       = "Wrong Project Objective"
        objectiveId = $objBId
    }
    # Contract says same-project integrity failures are 422.
    # The API must not silently accept a cross-project objective.
    if ($r31.Status -eq 422 -or $r31.Status -eq 404) {
        Record-Pass "Wrong-project objectiveId rejected (status=$($r31.Status))"
    } else {
        Record-Fail "Wrong-project objectiveId was accepted (cross-project leakage)" "got status=$($r31.Status)"
    }
} else {
    Record-Skip "Wrong-project objectiveId test (objective B creation failed)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 32: Create initiative with non-existent objectiveId (must fail)
# ---------------------------------------------------------------------------
Write-Host "[32] Create initiative with non-existent objectiveId rejected"

$fakeObjId = [guid]::NewGuid().ToString()
$initKey32 = "hci-fakeobj-$runSuffix"
$r32 = Invoke-Api "POST" "/api/projects/$projAId/initiatives" @{
    key         = $initKey32
    title       = "Non-existent Objective"
    objectiveId = $fakeObjId
}

# Missing parent should fail. The API may collapse missing and wrong-project
# into the same error code. Both 422 and 404 are acceptable.
if ($r32.Status -eq 422 -or $r32.Status -eq 404) {
    Record-Pass "Non-existent objectiveId rejected (status=$($r32.Status))"
} else {
    Record-Fail "Non-existent objectiveId accepted" "got status=$($r32.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 33: Create initiative with archived objectiveId (must fail with 422)
# ---------------------------------------------------------------------------
Write-Host "[33] Create initiative with archived objectiveId rejected (422)"

if ($objArcId) {
    $initKey33 = "hci-arcobj-$runSuffix"
    $r33 = Invoke-Api "POST" "/api/projects/$projAId/initiatives" @{
        key         = $initKey33
        title       = "Archived Objective Parent"
        objectiveId = $objArcId
    }
    if ($r33.Status -eq 422) {
        Record-Pass "Archived objectiveId rejected with 422"
    } else {
        Record-Fail "Archived objectiveId not rejected" "got status=$($r33.Status)"
    }
} else {
    Record-Skip "Archived objectiveId test (archived objective creation/archival failed)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 34: Create initiative with malformed objectiveId (must fail with 400)
# ---------------------------------------------------------------------------
Write-Host "[34] Create initiative with malformed objectiveId rejected (400)"

$initKey34 = "hci-malobj-$runSuffix"
$r34 = Invoke-Api "POST" "/api/projects/$projAId/initiatives" @{
    key         = $initKey34
    title       = "Malformed ObjectiveId"
    objectiveId = "not-a-uuid"
}
if ($r34.Status -eq 400) {
    Record-Pass "Malformed objectiveId rejected with 400"
} else {
    Record-Fail "Malformed objectiveId not rejected" "got status=$($r34.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 35: PATCH objectiveId to a wrong-project objective (must fail)
# ---------------------------------------------------------------------------
Write-Host "[35] PATCH objectiveId to wrong-project objective rejected"

# Use one of the initiatives created without objectiveId (initKeyNoObj from case 1b)
$initNoObjId = $resp1b.Body?.id
if ($initNoObjId -and $objBId) {
    $r35 = Invoke-Api "PATCH" "/api/projects/$projAId/initiatives/$initNoObjId" @{
        objectiveId = $objBId
    }
    if ($r35.Status -eq 422 -or $r35.Status -eq 404) {
        Record-Pass "PATCH with wrong-project objectiveId rejected (status=$($r35.Status))"
    } else {
        Record-Fail "PATCH with wrong-project objectiveId accepted (cross-project leakage)" "got status=$($r35.Status)"
    }
} else {
    Record-Skip "PATCH wrong-project objectiveId test (prerequisites missing)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 36: PATCH objectiveId to an archived objective (must fail with 422)
# ---------------------------------------------------------------------------
Write-Host "[36] PATCH objectiveId to archived objective rejected (422)"

if ($initNoObjId -and $objArcId) {
    $r36 = Invoke-Api "PATCH" "/api/projects/$projAId/initiatives/$initNoObjId" @{
        objectiveId = $objArcId
    }
    if ($r36.Status -eq 422) {
        Record-Pass "PATCH with archived objectiveId rejected with 422"
    } else {
        Record-Fail "PATCH with archived objectiveId not rejected" "got status=$($r36.Status)"
    }
} else {
    Record-Skip "PATCH archived objectiveId test (prerequisites missing)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 37: PATCH objectiveId reassignment to valid same-project objective
# ---------------------------------------------------------------------------
Write-Host "[37] PATCH objectiveId reassignment to valid same-project objective"

if ($initNoObjId -and $objAId) {
    $r37 = Invoke-Api "PATCH" "/api/projects/$projAId/initiatives/$initNoObjId" @{
        objectiveId = $objAId
    }
    if ($r37.Status -eq 200 -and $r37.Body?.objectiveId -eq $objAId) {
        Record-Pass "PATCH objectiveId reassignment to valid objective succeeds"
    } else {
        Record-Fail "PATCH objectiveId reassignment failed" "status=$($r37.Status)"
    }
} else {
    Record-Skip "PATCH objectiveId reassignment test (prerequisites missing)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# Cleanup: delete test data created during this run
# ---------------------------------------------------------------------------
Write-Host "[cleanup] Removing test data created this run (suffix=$runSuffix)..."

$cleanupSql = @"
DELETE FROM app.status_history
WHERE "entityId" IN (
    SELECT id FROM app.initiative WHERE key LIKE 'hci-%-$runSuffix'
) AND "entityType" = 'initiative';

DELETE FROM app.initiative WHERE key LIKE 'hci-%-$runSuffix';

DELETE FROM app.status_history
WHERE "entityId" IN (
    SELECT id FROM app.objective WHERE key LIKE 'hci-%-$runSuffix'
) AND "entityType" = 'objective';

DELETE FROM app.objective WHERE key LIKE 'hci-%-$runSuffix';

DELETE FROM app.status_history
WHERE "entityId" IN (
    SELECT id FROM app.project WHERE key LIKE 'hci-%-$runSuffix'
) AND "entityType" = 'project';

DELETE FROM app.project WHERE key LIKE 'hci-%-$runSuffix';
"@
$cleanupTmp = [System.IO.Path]::GetTempFileName() + ".sql"
[System.IO.File]::WriteAllText($cleanupTmp, $cleanupSql, [System.Text.Encoding]::UTF8)
try {
    $cleanupOut  = psql $ConnectionString --file $cleanupTmp 2>&1
    $cleanupExit = $LASTEXITCODE
} finally {
    Remove-Item -Force -ErrorAction SilentlyContinue $cleanupTmp
}

if ($cleanupExit -eq 0 -and ($cleanupOut -join "") -notmatch 'ERROR') {
    Write-Host "  Cleanup complete."
} else {
    Write-Host "  WARNING: cleanup may not have completed cleanly."
    Write-Host "  Output: $($cleanupOut -join ' ')"
}

Write-Host ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host "----------------------------------------"
Write-Host "hammer-core-initiatives  |  PASS: $passCount | SKIP: $skipCount | FAIL: $failCount"
Write-Host ""

if ($failCount -gt 0) { exit 1 } else { exit 0 }
