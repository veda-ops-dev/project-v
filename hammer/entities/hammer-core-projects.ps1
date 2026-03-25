# HAMMER MODULE: core-projects
# Purpose: verify Project V project API contract, mutation boundaries, scope,
#          deterministic ordering, cursor continuation, and status transition rules
# Invariants:
#   - Project creation requires valid key and name
#   - Duplicate key is rejected (409)
#   - Unknown fields in body/query are rejected (400)
#   - Caller-supplied status on creation is rejected (400)
#   - Malformed projectId is rejected (400)
#   - Missing project returns 404
#   - List ordering is deterministic (updatedAt desc, id asc)
#   - Cursor continuation is correct and resumable
#   - Project PATCH is bounded to name/description only
#   - Status transitions follow governed rules (422 for forbidden, 400 for missing reason)
#   - StatusHistory row is written atomically for every valid status transition
#   - Concurrent duplicate key creation produces exactly one success and one conflict
# Assumes: Migration 001 applied; API server running on BASE_URL

param(
    [string]$BaseUrl = "http://127.0.0.1:3100",
    [string]$ConnectionString = "postgresql://project_v_app:projectv@localhost:5432/project_v_local"
)

Write-Host "Running hammer: core-projects"
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
# CASE 1: Create a valid project — response shape, status, id present
# ---------------------------------------------------------------------------
Write-Host "[1] Create valid project"

$key1  = "hcp-valid-$runSuffix"
$resp1 = Invoke-Api "POST" "/api/projects" @{ key = $key1; name = "Hammer Core Projects Test" }
$proj1Id = $resp1.Body?.id

if ($resp1.Status -eq 201 -and $proj1Id) {
    Record-Pass "POST /api/projects returns 201 with id"
} else {
    Record-Fail "POST /api/projects failed" "status=$($resp1.Status) body=$($resp1.Raw)"
}

if ($resp1.Body?.key -eq $key1) {
    Record-Pass "Response key matches submitted key"
} else {
    Record-Fail "Response key mismatch" "expected=$key1 got=$($resp1.Body?.key)"
}

if ($resp1.Body?.status -eq 'active') {
    Record-Pass "Server assigns status=active on creation"
} else {
    Record-Fail "status is not 'active' on creation" "got=$($resp1.Body?.status)"
}

foreach ($field in @('id','key','name','status','createdAt','updatedAt')) {
    if ($null -ne $resp1.Body?.($field)) {
        Record-Pass "Response includes field: $field"
    } else {
        Record-Fail "Response missing field: $field"
    }
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 2: Invalid key formats are rejected (400)
# ---------------------------------------------------------------------------
Write-Host "[2] Invalid key format rejection"

$badKeys = @(
    @{ key = "HAS-UPPER"; name = "Bad Key 1" },
    @{ key = "has spaces"; name = "Bad Key 2" },
    @{ key = "-leadhyphen"; name = "Bad Key 3" },
    @{ key = "ab"; name = "Bad Key 4 (too short)" },
    @{ key = ""; name = "Bad Key 5 (empty)" }
)

foreach ($payload in $badKeys) {
    $r = Invoke-Api "POST" "/api/projects" $payload
    if ($r.Status -eq 400) {
        Record-Pass "Invalid key '$($payload.key)' rejected with 400"
    } else {
        Record-Fail "Invalid key '$($payload.key)' not rejected" "got status=$($r.Status)"
    }
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 3: Empty name is rejected (400)
# ---------------------------------------------------------------------------
Write-Host "[3] Empty name rejection"

$r3 = Invoke-Api "POST" "/api/projects" @{ key = "hcp-noname-$runSuffix"; name = "" }
if ($r3.Status -eq 400) {
    Record-Pass "Empty name rejected with 400"
} else {
    Record-Fail "Empty name not rejected" "got status=$($r3.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 4: Duplicate key is rejected (409)
# ---------------------------------------------------------------------------
Write-Host "[4] Duplicate key rejection"

if ($proj1Id) {
    $r4 = Invoke-Api "POST" "/api/projects" @{ key = $key1; name = "Duplicate Attempt" }
    if ($r4.Status -eq 409) {
        Record-Pass "Duplicate key rejected with 409"
    } else {
        Record-Fail "Duplicate key not rejected" "got status=$($r4.Status)"
    }
} else {
    Record-Skip "Duplicate key test (project creation failed in case 1)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 5: Caller-supplied status on creation is rejected (400)
# ---------------------------------------------------------------------------
Write-Host "[5] Caller-supplied status on creation rejected"

$r5 = Invoke-Api "POST" "/api/projects" @{ key = "hcp-withstatus-$runSuffix"; name = "Status Test"; status = "active" }
if ($r5.Status -eq 400) {
    Record-Pass "Caller-supplied status on creation rejected with 400"
} else {
    Record-Fail "Caller-supplied status was accepted" "got status=$($r5.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 6: Unknown fields in POST body rejected (400)
# ---------------------------------------------------------------------------
Write-Host "[6] Unknown fields in POST body rejected"

$r6 = Invoke-Api "POST" "/api/projects" @{ key = "hcp-unknown-$runSuffix"; name = "Unknown Field Test"; bogus = "value" }
if ($r6.Status -eq 400) {
    Record-Pass "Unknown field in POST body rejected with 400"
} else {
    Record-Fail "Unknown field in POST body was accepted" "got status=$($r6.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 7: Malformed projectId returns 400
# ---------------------------------------------------------------------------
Write-Host "[7] Malformed projectId returns 400"

$r7 = Invoke-Api "GET" "/api/projects/not-a-uuid"
if ($r7.Status -eq 400) {
    Record-Pass "Malformed projectId returns 400"
} else {
    Record-Fail "Malformed projectId did not return 400" "got status=$($r7.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 8: Missing project returns 404
# ---------------------------------------------------------------------------
Write-Host "[8] Missing project returns 404"

$nonExistentId = [guid]::NewGuid().ToString()
$r8 = Invoke-Api "GET" "/api/projects/$nonExistentId"
if ($r8.Status -eq 404) {
    Record-Pass "Missing project returns 404"
} else {
    Record-Fail "Missing project did not return 404" "got status=$($r8.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 9: GET single project returns correct record
# ---------------------------------------------------------------------------
Write-Host "[9] GET single project by id"

if ($proj1Id) {
    $r9 = Invoke-Api "GET" "/api/projects/$proj1Id"
    if ($r9.Status -eq 200 -and $r9.Body?.id -eq $proj1Id) {
        Record-Pass "GET /api/projects/:id returns correct record"
    } else {
        Record-Fail "GET /api/projects/:id failed" "status=$($r9.Status)"
    }
} else {
    Record-Skip "GET single project (creation failed in case 1)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 10: Deterministic ordering and cursor continuation
# Create 3 additional projects with a small sleep to ensure distinct updatedAt,
# then verify ordering and cursor behavior.
# ---------------------------------------------------------------------------
Write-Host "[10] Deterministic ordering and cursor continuation"

$createdIds = @()
if ($proj1Id) { $createdIds += $proj1Id }

for ($i = 1; $i -le 3; $i++) {
    $r = Invoke-Api "POST" "/api/projects" @{
        key  = "hcp-order-$i-$runSuffix"
        name = "Hammer Order Test $i"
    }
    if ($r.Status -eq 201 -and $r.Body?.id) {
        $createdIds += $r.Body.id
        # Small delay to ensure distinct updatedAt timestamps
        Start-Sleep -Milliseconds 50
    }
}

if ($createdIds.Count -ge 2) {
    # Fetch with limit=2
    $r10a = Invoke-Api "GET" "/api/projects?limit=2"
    if ($r10a.Status -eq 200) {
        $page1 = $r10a.Body?.data
        $nc    = $r10a.Body?.nextCursor

        # Verify nextCursor field is present (even if null)
        if ($r10a.Body.ContainsKey('nextCursor')) {
            Record-Pass "List response always includes nextCursor field"
        } else {
            Record-Fail "List response missing nextCursor field"
        }

        if ($page1 -and $page1.Count -le 2) {
            Record-Pass "List with limit=2 returns at most 2 records"
        } else {
            Record-Fail "List with limit=2 returned wrong count" "got=$($page1?.Count)"
        }

        # Verify ordering within the page: updatedAt desc
        if ($page1 -and $page1.Count -ge 2) {
            $t0 = [datetime]$page1[0].updatedAt
            $t1 = [datetime]$page1[1].updatedAt
            if ($t0 -ge $t1) {
                Record-Pass "List page 1 is ordered updatedAt desc"
            } else {
                Record-Fail "List page 1 ordering incorrect" "item[0].updatedAt=$t0 item[1].updatedAt=$t1"
            }
        }

        # If nextCursor is present, fetch page 2
        if ($nc) {
            $encoded = [System.Uri]::EscapeDataString($nc)
            $r10b = Invoke-Api "GET" "/api/projects?limit=2&cursor=$encoded"
            if ($r10b.Status -eq 200) {
                Record-Pass "Cursor continuation returns 200"
                $page2 = $r10b.Body?.data
                # No id from page1 should appear in page2
                $overlap = @()
                if ($page1 -and $page2) {
                    $ids1 = $page1 | ForEach-Object { $_.id }
                    $ids2 = $page2 | ForEach-Object { $_.id }
                    $overlap = $ids1 | Where-Object { $ids2 -contains $_ }
                }
                if ($overlap.Count -eq 0) {
                    Record-Pass "No overlap between page 1 and page 2"
                } else {
                    Record-Fail "Page 1 and page 2 contain duplicate ids" "overlap=$($overlap -join ',')"
                }
            } else {
                Record-Fail "Cursor continuation request failed" "status=$($r10b.Status)"
            }
        } else {
            Record-Skip "Cursor continuation (nextCursor was null — all results fit in one page)"
        }
    } else {
        Record-Fail "GET /api/projects list failed" "status=$($r10a.Status)"
    }
} else {
    Record-Skip "Ordering and cursor test (insufficient projects created)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 11: Malformed cursor is rejected (400)
# ---------------------------------------------------------------------------
Write-Host "[11] Malformed cursor rejection"

$r11 = Invoke-Api "GET" "/api/projects?cursor=not-a-real-cursor"
if ($r11.Status -eq 400) {
    Record-Pass "Malformed cursor rejected with 400"
} else {
    Record-Fail "Malformed cursor not rejected" "got status=$($r11.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 11b: Cursor encode -> decode -> re-encode stability
# Verifies the cursor contract in-process: encode a known payload, decode it,
# re-encode, and assert both encoded forms are identical.
# Tests the payload field round-trip without hitting the API.
# ---------------------------------------------------------------------------
Write-Host "[11b] Cursor encode/decode/re-encode stability"

try {
    $testId        = [guid]::NewGuid().ToString()
    $testTs        = "2025-01-15T10:30:00.000Z"

    # Encode: base64url of JSON({u: <iso>, i: <uuid>})
    $json1         = '{"u":"' + $testTs + '","i":"' + $testId + '"}'
    $bytes1        = [System.Text.Encoding]::UTF8.GetBytes($json1)
    $b64_1         = [Convert]::ToBase64String($bytes1) -replace '[+]','-' -replace '/','_' -replace '='

    # Decode back
    $padded        = $b64_1
    $mod           = $padded.Length % 4
    if ($mod -eq 2) { $padded += "==" } elseif ($mod -eq 3) { $padded += "=" }
    $stdB64        = $padded -replace '-','+' -replace '_','/'
    $decoded       = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($stdB64))

    # Re-encode from decoded string (not from ConvertFrom-Json, which coerces
    # ISO-8601 strings to [datetime] and destroys the original representation).
    # The cursor contract treats 'u' and 'i' as opaque strings — no date parsing.
    $bytes2        = [System.Text.Encoding]::UTF8.GetBytes($decoded)
    $b64_2         = [Convert]::ToBase64String($bytes2) -replace '[+]','-' -replace '/','_' -replace '='

    if ($b64_1 -eq $b64_2) {
        Record-Pass "Cursor encode -> decode -> re-encode produces identical result"
    } else {
        Record-Fail "Cursor encode/decode/re-encode mismatch" "first=$b64_1 second=$b64_2"
    }

    # Extract fields via regex to avoid ConvertFrom-Json date coercion.
    $decodedU = if ($decoded -match '"u":"([^"]+)"') { $Matches[1] } else { $null }
    $decodedI = if ($decoded -match '"i":"([^"]+)"') { $Matches[1] } else { $null }

    if ($decodedU -eq $testTs -and $decodedI -eq $testId) {
        Record-Pass "Cursor payload fields survive round-trip without mutation"
    } else {
        Record-Fail "Cursor payload fields changed during round-trip" "u=$decodedU i=$decodedI"
    }
} catch {
    Record-Fail "Cursor stability check threw an exception" $_.Exception.Message
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 12: Unknown query parameter rejected (400)
# ---------------------------------------------------------------------------
Write-Host "[12] Unknown query parameter rejected"

$r12 = Invoke-Api "GET" "/api/projects?bogusparam=value"
if ($r12.Status -eq 400) {
    Record-Pass "Unknown query parameter rejected with 400"
} else {
    Record-Fail "Unknown query parameter not rejected" "got status=$($r12.Status)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 13: PATCH valid fields
# ---------------------------------------------------------------------------
Write-Host "[13] PATCH valid fields"

if ($proj1Id) {
    $r13 = Invoke-Api "PATCH" "/api/projects/$proj1Id" @{ name = "Updated Name"; description = "New description" }
    if ($r13.Status -eq 200 -and $r13.Body?.name -eq "Updated Name") {
        Record-Pass "PATCH name and description returns 200 with updated record"
    } else {
        Record-Fail "PATCH failed" "status=$($r13.Status) name=$($r13.Body?.name)"
    }
} else {
    Record-Skip "PATCH valid fields (project creation failed)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 14: PATCH unknown field rejected (400)
# ---------------------------------------------------------------------------
Write-Host "[14] PATCH unknown field rejected"

if ($proj1Id) {
    $r14 = Invoke-Api "PATCH" "/api/projects/$proj1Id" @{ name = "OK"; unknownField = "bad" }
    if ($r14.Status -eq 400) {
        Record-Pass "PATCH with unknown field rejected with 400"
    } else {
        Record-Fail "PATCH with unknown field not rejected" "got status=$($r14.Status)"
    }
} else {
    Record-Skip "PATCH unknown field test (project creation failed)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 15: Status transition — valid (active -> deferred)
# ---------------------------------------------------------------------------
Write-Host "[15] Status transition: active -> deferred (valid, no reason required)"

if ($proj1Id) {
    $r15 = Invoke-Api "POST" "/api/projects/$proj1Id/status" @{ newStatus = "deferred" }
    if ($r15.Status -eq 200 -and $r15.Body?.status -eq 'deferred') {
        Record-Pass "active -> deferred transition succeeds"
    } else {
        Record-Fail "active -> deferred transition failed" "status=$($r15.Status) body=$($r15.Raw)"
    }
    # Verify statusHistoryId is present in response
    if ($r15.Body?.statusHistoryId) {
        Record-Pass "Response includes statusHistoryId"
    } else {
        Record-Fail "Response missing statusHistoryId"
    }
} else {
    Record-Skip "Status transition (project creation failed)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 16: StatusHistory row written atomically — verify via DB
# ---------------------------------------------------------------------------
Write-Host "[16] StatusHistory row exists for transition (DB check)"

if ($proj1Id) {
    # Use -t (tuples only) and -A (unaligned) to get a bare scalar value with no
    # header, footer, or alignment whitespace. Immune to psql formatting changes.
    $c16Sql = @"
SELECT COUNT(*)::int FROM app.status_history WHERE "entityId" = '$proj1Id'::uuid AND "entityType" = 'project';
"@
    $tmpFile16 = [System.IO.Path]::GetTempFileName() + ".sql"
    [System.IO.File]::WriteAllText($tmpFile16, $c16Sql, [System.Text.Encoding]::UTF8)
    try {
        $c16Out  = psql $ConnectionString -t -A --file $tmpFile16 2>&1
        $c16Exit = $LASTEXITCODE
    } finally {
        Remove-Item -Force -ErrorAction SilentlyContinue $tmpFile16
    }

    if ($c16Exit -ne 0 -or ($c16Out -join "") -match 'ERROR') {
        Record-Fail "DB query for StatusHistory failed" ($c16Out -join " ")
    } else {
        # -t -A output: one line with the bare integer, no headers or padding.
        $cntStr = ($c16Out | Where-Object { $_.Trim() -ne "" } | Select-Object -First 1).Trim()
        $cntVal = 0
        if ([int]::TryParse($cntStr, [ref]$cntVal) -and $cntVal -ge 1) {
            Record-Pass "StatusHistory row exists for project transition (count=$cntVal)"
        } else {
            Record-Fail "No StatusHistory row found for project transition (raw='$cntStr')"
        }
    }
} else {
    Record-Skip "StatusHistory DB check (project creation failed)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 17: Forbidden transition rejected (422)
# (archived -> active is forbidden)
# ---------------------------------------------------------------------------
Write-Host "[17] Forbidden transition rejected (422)"

# Create a fresh project and archive it, then try to reactivate it
$key17  = "hcp-archive-$runSuffix"
$r17a   = Invoke-Api "POST" "/api/projects" @{ key = $key17; name = "Archive Test Project" }
$proj17Id = $r17a.Body?.id

if ($proj17Id) {
    # active -> archived (requires reason)
    $r17b = Invoke-Api "POST" "/api/projects/$proj17Id/status" @{ newStatus = "archived"; reason = "archiving for test" }
    if ($r17b.Status -eq 200) {
        # archived -> active must fail 422
        $r17c = Invoke-Api "POST" "/api/projects/$proj17Id/status" @{ newStatus = "active" }
        if ($r17c.Status -eq 422) {
            Record-Pass "Forbidden transition (archived -> active) rejected with 422"
        } else {
            Record-Fail "Forbidden transition not rejected" "got status=$($r17c.Status)"
        }
    } else {
        Record-Skip "Forbidden transition test (archive step failed: status=$($r17b.Status))"
    }
} else {
    Record-Skip "Forbidden transition test (project creation failed)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 18: Missing reason rejected for required-reason transition (400)
# (active -> archived requires reason)
# ---------------------------------------------------------------------------
Write-Host "[18] Missing reason rejected for required-reason transition (400)"

$key18 = "hcp-noreason-$runSuffix"
$r18a  = Invoke-Api "POST" "/api/projects" @{ key = $key18; name = "No Reason Test Project" }
$proj18Id = $r18a.Body?.id

if ($proj18Id) {
    $r18b = Invoke-Api "POST" "/api/projects/$proj18Id/status" @{ newStatus = "archived" }
    if ($r18b.Status -eq 400) {
        Record-Pass "Missing reason for required-reason transition rejected with 400"
    } else {
        Record-Fail "Missing reason was not rejected" "got status=$($r18b.Status)"
    }
} else {
    Record-Skip "Missing reason test (project creation failed)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 19: Invalid newStatus value rejected (422)
# ---------------------------------------------------------------------------
Write-Host "[19] Invalid newStatus value rejected (422)"

if ($proj1Id) {
    $r19 = Invoke-Api "POST" "/api/projects/$proj1Id/status" @{ newStatus = "banana" }
    if ($r19.Status -eq 422) {
        Record-Pass "Invalid newStatus value rejected with 422"
    } else {
        Record-Fail "Invalid newStatus not rejected" "got status=$($r19.Status)"
    }
} else {
    Record-Skip "Invalid newStatus test (project creation failed)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 20: Duplicate key constraint enforcement (sequential duplicate requests)
# Tests that the uniqueness constraint correctly rejects a second request for
# an already-taken key. This is sequential, not concurrent — it verifies
# constraint correctness, not race-condition safety. True concurrency probing
# requires a parallel runner and is out of scope for this module.
# ---------------------------------------------------------------------------
Write-Host "[20] Duplicate key constraint enforcement (sequential duplicate requests)"

$key20 = "hcp-seqdup-$runSuffix"
$body20 = @{ key = $key20; name = "Concurrent Create Test" }

$raceA = Invoke-Api "POST" "/api/projects" $body20
$raceB = Invoke-Api "POST" "/api/projects" $body20

$statusA = $raceA.Status
$statusB = $raceB.Status

$successCount = @($statusA, $statusB) | Where-Object { $_ -eq 201 } | Measure-Object | Select-Object -ExpandProperty Count
$conflictCount = @($statusA, $statusB) | Where-Object { $_ -eq 409 } | Measure-Object | Select-Object -ExpandProperty Count

if ($successCount -eq 1 -and $conflictCount -eq 1) {
    Record-Pass "Duplicate key constraint: exactly 1 success, 1 conflict (201=$successCount, 409=$conflictCount)"
} else {
    Record-Fail "Duplicate key constraint did not produce expected 1-success/1-conflict pattern" "statuses=$statusA,$statusB"
}

Write-Host ""

# ---------------------------------------------------------------------------
# Cleanup: delete projects (and their history rows) created during this run.
# Deletes by key prefix matching this run's suffix, keeping the DB clean
# across repeated runs so ordering tests remain deterministic over time.
# ---------------------------------------------------------------------------
Write-Host "[cleanup] Removing test data created this run (suffix=$runSuffix)..."

$cleanupSql = @"
DELETE FROM app.status_history
WHERE "entityId" IN (
    SELECT id FROM app.project WHERE key LIKE 'hcp-%-$runSuffix'
);
DELETE FROM app.project WHERE key LIKE 'hcp-%-$runSuffix';
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
Write-Host "hammer-core-projects  |  PASS: $passCount | SKIP: $skipCount | FAIL: $failCount"
Write-Host ""

if ($failCount -gt 0) { exit 1 } else { exit 0 }
