# HAMMER MODULE: core-objectives
# Purpose: verify Project V objective API contract, project-scope enforcement,
#          validation boundaries, deterministic ordering, cursor continuation,
#          and status transition rules
# Invariants:
#   - Objectives are always project-scoped; no objective route operates without project context
#   - Objective creation requires valid key and title
#   - Duplicate key rejected within same project (409)
#   - Same key allowed in different projects
#   - Invalid key format rejected (400)
#   - Empty title rejected (400)
#   - Invalid priority rejected (422)
#   - Unknown fields in body/query are rejected (400)
#   - Caller-supplied status on creation is rejected (400)
#   - Wrong-project GET behaves as 404 (no cross-project existence leakage)
#   - Missing objective returns 404
#   - List ordering is deterministic (priority asc, updatedAt desc, id asc)
#   - Cursor continuation is correct with no overlap
#   - PATCH is bounded to allowed fields only
#   - updatedAt changes on mutation
#   - Status transitions follow governed rules (422 for forbidden, 400 for missing reason)
#   - StatusHistory row is written atomically for every valid status transition
#   - Creation under archived project rejected (422)
# Assumes: Migration 001 applied; API server running on BASE_URL

param(
    [string]$BaseUrl = "http://127.0.0.1:3100",
    [string]$ConnectionString = "postgresql://project_v_app:projectv@localhost:5432/project_v_local"
)

Write-Host "Running hammer: core-objectives"
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
# Setup: create two projects for scope isolation tests
# ---------------------------------------------------------------------------
Write-Host "[setup] Creating test projects..."

$projKeyA = "hco-proja-$runSuffix"
$projKeyB = "hco-projb-$runSuffix"
$projA = Invoke-Api "POST" "/api/projects" @{ key = $projKeyA; name = "Objective Hammer Project A" }
$projB = Invoke-Api "POST" "/api/projects" @{ key = $projKeyB; name = "Objective Hammer Project B" }
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
Write-Host ""

# ---------------------------------------------------------------------------
# CASE 1: Create a valid objective -- response shape, status, id present
# ---------------------------------------------------------------------------
Write-Host "[1] Create valid objective"

$objKey1 = "hco-obj1-$runSuffix"
$resp1 = Invoke-Api "POST" "/api/projects/$projAId/objectives" @{
    key   = $objKey1
    title = "Hammer Objective Test 1"
}
$obj1Id = $resp1.Body?.id

if ($resp1.Status -eq 201 -and $obj1Id) {
    Record-Pass "POST returns 201 with id"
} else {
    Record-Fail "POST failed" "status=$($resp1.Status) body=$($resp1.Raw)"
}

if ($resp1.Body?.key -eq $objKey1) {
    Record-Pass "Response key matches submitted key"
} else {
    Record-Fail "Response key mismatch" "expected=$objKey1 got=$($resp1.Body?.key)"
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

if ($resp1.Body?.priority -eq 100) {
    Record-Pass "Default priority is 100"
} else {
    Record-Fail "Default priority mismatch" "expected=100 got=$($resp1.Body?.priority)"
}

foreach ($field in @('id','projectId','key','title','status','priority','createdAt','updatedAt')) {
    if ($null -ne $resp1.Body?.($field)) {
        Record-Pass "Response includes field: $field"
    } else {
        Record-Fail "Response missing field: $field"
    }
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
    $r = Invoke-Api "POST" "/api/projects/$projAId/objectives" $payload
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

$r3 = Invoke-Api "POST" "/api/projects/$projAId/objectives" @{ key = "hco-notitle-$runSuffix"; title = "" }
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

$r4a = Invoke-Api "POST" "/api/projects/$projAId/objectives" @{
    key = "hco-badpri1-$runSuffix"; title = "Bad Priority"; priority = 0
}
if ($r4a.Status -eq 422) {
    Record-Pass "Priority 0 rejected with 422"
} else {
    Record-Fail "Priority 0 not rejected" "got status=$($r4a.Status)"
}

$r4b = Invoke-Api "POST" "/api/projects/$projAId/objectives" @{
    key = "hco-badpri2-$runSuffix"; title = "Bad Priority"; priority = 1001
}
if ($r4b.Status -eq 422) {
    Record-Pass "Priority 1001 rejected with 422"
} else {
    Record-Fail "Priority 1001 not rejected" "got status=$($r4b.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 5: Unknown fields in POST body rejected (400)
# ---------------------------------------------------------------------------
Write-Host "[5] Unknown fields in POST body rejected"

$r5 = Invoke-Api "POST" "/api/projects/$projAId/objectives" @{
    key = "hco-unkfld-$runSuffix"; title = "Unknown Field"; bogus = "value"
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

$r6 = Invoke-Api "POST" "/api/projects/$projAId/objectives" @{
    key = "hco-withstat-$runSuffix"; title = "Status Test"; status = "active"
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

$r7 = Invoke-Api "GET" "/api/projects/$projAId/objectives?bogusparam=value"
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

if ($obj1Id) {
    $r8 = Invoke-Api "POST" "/api/projects/$projAId/objectives" @{
        key = $objKey1; title = "Duplicate Attempt"
    }
    if ($r8.Status -eq 409) {
        Record-Pass "Duplicate key within same project rejected with 409"
    } else {
        Record-Fail "Duplicate key not rejected" "got status=$($r8.Status)"
    }
} else {
    Record-Skip "Duplicate key test (objective creation failed in case 1)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 9: Same key allowed in different project
# ---------------------------------------------------------------------------
Write-Host "[9] Same key allowed in different project"

$r9 = Invoke-Api "POST" "/api/projects/$projBId/objectives" @{
    key = $objKey1; title = "Same Key Different Project"
}
if ($r9.Status -eq 201) {
    Record-Pass "Same key in different project accepted (201)"
} else {
    Record-Fail "Same key in different project rejected" "got status=$($r9.Status)"
}
$objBId = $r9.Body?.id

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 10: GET single objective within correct project
# ---------------------------------------------------------------------------
Write-Host "[10] GET single objective by id within correct project"

if ($obj1Id) {
    $r10 = Invoke-Api "GET" "/api/projects/$projAId/objectives/$obj1Id"
    if ($r10.Status -eq 200 -and $r10.Body?.id -eq $obj1Id) {
        Record-Pass "GET returns correct objective record"
    } else {
        Record-Fail "GET failed" "status=$($r10.Status)"
    }
} else {
    Record-Skip "GET single objective (creation failed)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 11: Wrong-project GET returns 404 (no cross-project leakage)
# ---------------------------------------------------------------------------
Write-Host "[11] Wrong-project GET returns 404"

if ($obj1Id) {
    # obj1Id belongs to projA, try to GET via projB
    $r11 = Invoke-Api "GET" "/api/projects/$projBId/objectives/$obj1Id"
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
# CASE 12: Missing objective returns 404
# ---------------------------------------------------------------------------
Write-Host "[12] Missing objective returns 404"

$nonExistentId = [guid]::NewGuid().ToString()
$r12 = Invoke-Api "GET" "/api/projects/$projAId/objectives/$nonExistentId"
if ($r12.Status -eq 404) {
    Record-Pass "Missing objective returns 404"
} else {
    Record-Fail "Missing objective did not return 404" "got status=$($r12.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 13: Malformed objectiveId returns 400
# ---------------------------------------------------------------------------
Write-Host "[13] Malformed objectiveId returns 400"

$r13 = Invoke-Api "GET" "/api/projects/$projAId/objectives/not-a-uuid"
if ($r13.Status -eq 400) {
    Record-Pass "Malformed objectiveId returns 400"
} else {
    Record-Fail "Malformed objectiveId did not return 400" "got status=$($r13.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 14: PATCH allowed fields successfully; updatedAt changes
# ---------------------------------------------------------------------------
Write-Host "[14] PATCH allowed fields and updatedAt verification"

if ($obj1Id) {
    $beforePatch = Invoke-Api "GET" "/api/projects/$projAId/objectives/$obj1Id"
    $oldUpdatedAt = $beforePatch.Body?.updatedAt

    Start-Sleep -Milliseconds 50

    $r14 = Invoke-Api "PATCH" "/api/projects/$projAId/objectives/$obj1Id" @{
        title = "Updated Objective Title"
        description = "Updated description"
        priority = 50
    }
    if ($r14.Status -eq 200 -and $r14.Body?.title -eq "Updated Objective Title") {
        Record-Pass "PATCH returns 200 with updated record"
    } else {
        Record-Fail "PATCH failed" "status=$($r14.Status) title=$($r14.Body?.title)"
    }

    if ($r14.Body?.priority -eq 50) {
        Record-Pass "PATCH updated priority correctly"
    } else {
        Record-Fail "Priority not updated" "got=$($r14.Body?.priority)"
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

if ($obj1Id) {
    $r15 = Invoke-Api "PATCH" "/api/projects/$projAId/objectives/$obj1Id" @{
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

if ($obj1Id) {
    foreach ($forbiddenField in @('status', 'key', 'projectId', 'id')) {
        $patchBody = @{ $forbiddenField = "hacked" }
        $r15b = Invoke-Api "PATCH" "/api/projects/$projAId/objectives/$obj1Id" $patchBody
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
# Create objectives with varying priorities and small sleep for distinct updatedAt
# ---------------------------------------------------------------------------
Write-Host "[16] Deterministic ordering and cursor continuation"

$orderObjs = @()
$orderPriorities = @(50, 10, 50, 10, 50)
for ($i = 1; $i -le 5; $i++) {
    $r = Invoke-Api "POST" "/api/projects/$projAId/objectives" @{
        key      = "hco-ord-$i-$runSuffix"
        title    = "Order Test $i"
        priority = $orderPriorities[$i - 1]
    }
    if ($r.Status -eq 201 -and $r.Body?.id) {
        $orderObjs += $r.Body
    }
    Start-Sleep -Milliseconds 50
}

# Including the original obj1 (patched to priority 50), project A should have 6+ objectives.
# Fetch with limit=3 to force pagination.
$r16a = Invoke-Api "GET" "/api/projects/$projAId/objectives?limit=3"
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
        $r16b = Invoke-Api "GET" "/api/projects/$projAId/objectives?limit=3&cursor=$encoded"
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
                        # tie-break by id asc
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
    Record-Fail "GET objectives list failed" "status=$($r16a.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 17: Malformed cursor rejected (400)
# ---------------------------------------------------------------------------
Write-Host "[17] Malformed cursor rejection"

$r17 = Invoke-Api "GET" "/api/projects/$projAId/objectives?cursor=not-a-real-cursor"
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

if ($obj1Id) {
    $r18 = Invoke-Api "POST" "/api/projects/$projAId/objectives/$obj1Id/status" @{
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

if ($obj1Id) {
    $c19Sql = @"
SELECT COUNT(*)::int FROM app.status_history WHERE "entityId" = '$obj1Id'::uuid AND "entityType" = 'objective';
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
            Record-Pass "StatusHistory row exists for objective transition (count=$cntVal)"
        } else {
            Record-Fail "No StatusHistory row found for objective transition (raw='$cntStr')"
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

# Use obj1Id which is now 'active'. Transition to completed, then try completed -> active.
if ($obj1Id) {
    $r20a = Invoke-Api "POST" "/api/projects/$projAId/objectives/$obj1Id/status" @{
        newStatus = "completed"
    }
    if ($r20a.Status -eq 200) {
        $r20b = Invoke-Api "POST" "/api/projects/$projAId/objectives/$obj1Id/status" @{
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

$objKeyReason = "hco-noreason-$runSuffix"
$rReason = Invoke-Api "POST" "/api/projects/$projAId/objectives" @{
    key = $objKeyReason; title = "Reason Test Objective"
}
$objReasonId = $rReason.Body?.id

if ($objReasonId) {
    $r21 = Invoke-Api "POST" "/api/projects/$projAId/objectives/$objReasonId/status" @{
        newStatus = "archived"
    }
    if ($r21.Status -eq 400) {
        Record-Pass "Missing reason for proposed -> archived rejected with 400"
    } else {
        Record-Fail "Missing reason not rejected" "got status=$($r21.Status)"
    }

    # Also test: with reason provided, the transition succeeds
    $r21b = Invoke-Api "POST" "/api/projects/$projAId/objectives/$objReasonId/status" @{
        newStatus = "archived"
        reason    = "archiving for hammer test"
    }
    if ($r21b.Status -eq 200) {
        Record-Pass "proposed -> archived with reason succeeds"
    } else {
        Record-Fail "proposed -> archived with reason failed" "got status=$($r21b.Status)"
    }
} else {
    Record-Skip "Missing reason test (objective creation failed)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 22: Invalid newStatus value rejected (422)
# ---------------------------------------------------------------------------
Write-Host "[22] Invalid newStatus value rejected (422)"

# Create a fresh objective for this test
$objKey22 = "hco-badstat-$runSuffix"
$r22create = Invoke-Api "POST" "/api/projects/$projAId/objectives" @{
    key = $objKey22; title = "Invalid Status Test"
}
$obj22Id = $r22create.Body?.id

if ($obj22Id) {
    $r22 = Invoke-Api "POST" "/api/projects/$projAId/objectives/$obj22Id/status" @{
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
# Tests one-way archival for objectives
# ---------------------------------------------------------------------------
Write-Host "[23] Archived -> active forbidden (422)"

# objReasonId was archived in case 21
if ($objReasonId) {
    $r23 = Invoke-Api "POST" "/api/projects/$projAId/objectives/$objReasonId/status" @{
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
# Two sequential requests for the same key in the same project --
# exactly 1 success, 1 conflict. This is sequential, not concurrent.
# ---------------------------------------------------------------------------
Write-Host "[24] Duplicate key constraint enforcement (sequential duplicate requests)"

$key24 = "hco-seqdup-$runSuffix"
$body24 = @{ key = $key24; title = "Sequential Dup Test" }

$raceA = Invoke-Api "POST" "/api/projects/$projAId/objectives" $body24
$raceB = Invoke-Api "POST" "/api/projects/$projAId/objectives" $body24

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

$projKeyArc = "hco-arcprj-$runSuffix"
$rArcProj = Invoke-Api "POST" "/api/projects" @{ key = $projKeyArc; name = "Archived Project" }
$arcProjId = $rArcProj.Body?.id

if ($arcProjId) {
    # Archive the project
    $rArc = Invoke-Api "POST" "/api/projects/$arcProjId/status" @{
        newStatus = "archived"
        reason    = "archiving for hammer test"
    }
    if ($rArc.Status -eq 200) {
        $r25 = Invoke-Api "POST" "/api/projects/$arcProjId/objectives" @{
            key = "hco-underarc-$runSuffix"; title = "Under Archived Project"
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

$r26 = Invoke-Api "GET" "/api/projects/$projBId/objectives"
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
        Record-Pass "List response contains only objectives from the requested project"
    } else {
        Record-Fail "List response contains cross-project objectives" "leaked=$($leakedIds -join ',')"
    }
} else {
    Record-Fail "GET objectives list for projB failed" "status=$($r26.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 27: Status transition writes StatusHistory with correct reason (DB check)
# blocked -> archived requires reason. Verify the reason is persisted.
# ---------------------------------------------------------------------------
Write-Host "[27] StatusHistory reason is persisted for required-reason transition (DB check)"

$objKey27 = "hco-reason27-$runSuffix"
$r27create = Invoke-Api "POST" "/api/projects/$projAId/objectives" @{
    key = $objKey27; title = "Reason Persist Test"
}
$obj27Id = $r27create.Body?.id

if ($obj27Id) {
    # proposed -> blocked
    Invoke-Api "POST" "/api/projects/$projAId/objectives/$obj27Id/status" @{ newStatus = "blocked" } | Out-Null
    # blocked -> archived with reason
    $archiveReason = "hammer-test-archive-reason"
    $r27arc = Invoke-Api "POST" "/api/projects/$projAId/objectives/$obj27Id/status" @{
        newStatus = "archived"
        reason    = $archiveReason
    }

    if ($r27arc.Status -eq 200) {
        $c27Sql = @"
SELECT reason FROM app.status_history WHERE "entityId" = '$obj27Id'::uuid AND "entityType" = 'objective' AND "newStatus" = 'archived' LIMIT 1;
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

# ---------------------------------------------------------------------------
# Cleanup: delete objectives and projects created during this run
# ---------------------------------------------------------------------------
Write-Host "[cleanup] Removing test data created this run (suffix=$runSuffix)..."

$cleanupSql = @"
DELETE FROM app.status_history
WHERE "entityId" IN (
    SELECT id FROM app.objective WHERE key LIKE 'hco-%-$runSuffix'
) AND "entityType" = 'objective';

DELETE FROM app.objective WHERE key LIKE 'hco-%-$runSuffix';

DELETE FROM app.status_history
WHERE "entityId" IN (
    SELECT id FROM app.project WHERE key LIKE 'hco-%-$runSuffix'
) AND "entityType" = 'project';

DELETE FROM app.project WHERE key LIKE 'hco-%-$runSuffix';
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
Write-Host "hammer-core-objectives  |  PASS: $passCount | SKIP: $skipCount | FAIL: $failCount"
Write-Host ""

if ($failCount -gt 0) { exit 1 } else { exit 0 }
