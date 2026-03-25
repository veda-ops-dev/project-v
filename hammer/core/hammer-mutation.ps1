# HAMMER MODULE: mutation
# Purpose: verify DB-level enforcement of mutation boundaries and constraints
# Invariants: NOT NULL, CHECK constraints, controlled vocabulary, numeric range,
#             unique scoped key, cross-project key isolation
# Assumes: Migration 001 has been applied (app schema + all 15 canonical tables exist)

param(
    [string]$ConnectionString = "postgresql://project_v_app:projectv@localhost:5432/project_v_local"
)

Write-Host "Running hammer: mutation"
Write-Host ""

# ---------------------------------------------------------------------------
# Helper: execute SQL via temp file.
# Returns a hashtable { Text: string; Code: int }.
# ExitCode is captured on the very next line after psql returns so nothing
# can overwrite $LASTEXITCODE before it is saved.
# ---------------------------------------------------------------------------
function Invoke-Sql($Sql) {
    $tmpFile = [System.IO.Path]::GetTempFileName()
    $sqlFile = $tmpFile + ".sql"
    Move-Item -Force $tmpFile $sqlFile
    try {
        [System.IO.File]::WriteAllText($sqlFile, $Sql, [System.Text.Encoding]::UTF8)
        $output   = psql $ConnectionString --file $sqlFile 2>&1
        $exitCode = $LASTEXITCODE
        return @{ Text = ($output -join "`n"); Code = $exitCode }
    }
    finally {
        Remove-Item -Force -ErrorAction SilentlyContinue $sqlFile
    }
}

# Evaluates the explicit result hashtable. Never reads ambient $LASTEXITCODE.
function Was-Rejected($result) {
    return ($result.Code -ne 0) -or ($result.Text -match 'ERROR')
}

# ---------------------------------------------------------------------------
# Tally
# ---------------------------------------------------------------------------
$passCount = 0
$skipCount = 0
$failCount = 0

function Record-Pass($label) { Write-Host "  PASS: $label"; $script:passCount++ }
function Record-Skip($label) { Write-Host "  SKIP: $label"; $script:skipCount++ }
function Record-Fail($label, $detail) {
    Write-Host "  FAIL: $label"
    if ($detail) { Write-Host "        $detail" }
    $script:failCount++
}
function Record-Info($label) { Write-Host "  INFO: $label" }

# ---------------------------------------------------------------------------
# Setup
# The shared project is committed as an FK anchor for cases 3/4/5.
# Per-run key suffix prevents key collision on repeated runs.
# All subtest data is wrapped in BEGIN/ROLLBACK -- nothing accumulates.
# ---------------------------------------------------------------------------
$runKey     = ([guid]::NewGuid().ToString()).Substring(0, 8)
$sharedProj = [guid]::NewGuid().ToString()

Write-Host "  Setup: creating shared project (key=hm-shared-$runKey)..."

$setupSql = @'
INSERT INTO app.project (id, key, name)
VALUES ('HSHAREDPROJ', 'hm-shared-HRKEY', 'Hammer Mutation Shared Project');
'@
$setupSql = $setupSql.Replace('HSHAREDPROJ', $sharedProj).Replace('HRKEY', $runKey)

$setupResult = Invoke-Sql $setupSql
if (Was-Rejected $setupResult) {
    Write-Host ""
    Write-Host "FAIL: could not create shared project -- setup failed. Cannot continue."
    Write-Host "      psql output: $($setupResult.Text)"
    exit 1
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 1: Missing required NOT NULL field is rejected
# Target: app.project missing 'name' (NOT NULL, no default)
# ---------------------------------------------------------------------------
Write-Host "[1] Missing required field (app.project missing name)"

$c1Id  = [guid]::NewGuid().ToString()
$c1Sql = @'
BEGIN;
INSERT INTO app.project (id, key)
VALUES ('HID1', 'hm-nonull-HRKEY');
ROLLBACK;
'@
$c1Sql = $c1Sql.Replace('HID1', $c1Id).Replace('HRKEY', $runKey)

$c1Result = Invoke-Sql $c1Sql
if (Was-Rejected $c1Result) {
    Record-Pass "DB rejected insert with missing NOT NULL field (name)"
} else {
    Record-Fail "DB accepted insert missing required NOT NULL field (name)" $c1Result.Text
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 2: Invalid controlled vocabulary value is rejected
# Target: app.project.status = 'banana' (must be active | deferred | archived)
# ---------------------------------------------------------------------------
Write-Host "[2] Invalid controlled vocabulary (app.project.status = 'banana')"

$c2Id  = [guid]::NewGuid().ToString()
$c2Sql = @'
BEGIN;
INSERT INTO app.project (id, key, name, status)
VALUES ('HID1', 'hm-vocab-HRKEY', 'Hammer Vocab Test', 'banana');
ROLLBACK;
'@
$c2Sql = $c2Sql.Replace('HID1', $c2Id).Replace('HRKEY', $runKey)

$c2Result = Invoke-Sql $c2Sql
if (Was-Rejected $c2Result) {
    Record-Pass "DB rejected insert with invalid status vocabulary value 'banana'"
} else {
    Record-Fail "DB accepted invalid controlled vocabulary value 'banana' for project.status" $c2Result.Text
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 3: Out-of-range numeric value is rejected
# Target: app.objective.priority -- allowed range 1..1000
# ---------------------------------------------------------------------------
Write-Host "[3a] Out-of-range numeric value (app.objective.priority = 0)"

$c3aId  = [guid]::NewGuid().ToString()
$c3aSql = @'
BEGIN;
INSERT INTO app.objective (id, "projectId", key, title, priority)
VALUES ('HID1', 'HSHAREDPROJ', 'hm-pri-low-HRKEY', 'Priority Zero Test', 0);
ROLLBACK;
'@
$c3aSql = $c3aSql.Replace('HID1', $c3aId).Replace('HSHAREDPROJ', $sharedProj).Replace('HRKEY', $runKey)

$c3aResult = Invoke-Sql $c3aSql
if (Was-Rejected $c3aResult) {
    Record-Pass "DB rejected objective.priority = 0 (below minimum 1)"
} else {
    Record-Fail "DB accepted objective.priority = 0 -- out-of-range value not rejected" $c3aResult.Text
}

Write-Host ""
Write-Host "[3b] Out-of-range numeric value (app.objective.priority = 1001)"

$c3bId  = [guid]::NewGuid().ToString()
$c3bSql = @'
BEGIN;
INSERT INTO app.objective (id, "projectId", key, title, priority)
VALUES ('HID1', 'HSHAREDPROJ', 'hm-pri-high-HRKEY', 'Priority 1001 Test', 1001);
ROLLBACK;
'@
$c3bSql = $c3bSql.Replace('HID1', $c3bId).Replace('HSHAREDPROJ', $sharedProj).Replace('HRKEY', $runKey)

$c3bResult = Invoke-Sql $c3bSql
if (Was-Rejected $c3bResult) {
    Record-Pass "DB rejected objective.priority = 1001 (above maximum 1000)"
} else {
    Record-Fail "DB accepted objective.priority = 1001 -- out-of-range value not rejected" $c3bResult.Text
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 4: Empty required text field is rejected when CHECK exists
# Target: app.objective.title = ''
# ---------------------------------------------------------------------------
Write-Host "[4] Empty required text field (app.objective.title = '')"

$c4Id  = [guid]::NewGuid().ToString()
$c4Sql = @'
BEGIN;
INSERT INTO app.objective (id, "projectId", key, title)
VALUES ('HID1', 'HSHAREDPROJ', 'hm-emptytitle-HRKEY', '');
ROLLBACK;
'@
$c4Sql = $c4Sql.Replace('HID1', $c4Id).Replace('HSHAREDPROJ', $sharedProj).Replace('HRKEY', $runKey)

$c4Result = Invoke-Sql $c4Sql
if (Was-Rejected $c4Result) {
    Record-Pass "DB rejected objective with empty title (CHECK enforced)"
} else {
    Record-Fail "DB accepted objective with empty title -- CHECK constraint missing or not enforced" $c4Result.Text
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 5: Duplicate scoped unique key is rejected within the same project
# Both inserts run inside one transaction. psql aborts on the duplicate;
# ROLLBACK ensures neither row persists.
# ---------------------------------------------------------------------------
Write-Host "[5] Duplicate scoped unique key rejected within same project"

$c5ObjA = [guid]::NewGuid().ToString()
$c5ObjB = [guid]::NewGuid().ToString()
$c5Sql  = @'
BEGIN;
INSERT INTO app.objective (id, "projectId", key, title)
VALUES ('HOBJA', 'HSHAREDPROJ', 'hm-dupkey-HRKEY', 'Objective Dup First');
INSERT INTO app.objective (id, "projectId", key, title)
VALUES ('HOBJB', 'HSHAREDPROJ', 'hm-dupkey-HRKEY', 'Objective Dup Second');
ROLLBACK;
'@
$c5Sql = $c5Sql.Replace('HOBJA', $c5ObjA).Replace('HOBJB', $c5ObjB)
$c5Sql = $c5Sql.Replace('HSHAREDPROJ', $sharedProj).Replace('HRKEY', $runKey)

$c5Result = Invoke-Sql $c5Sql
if (Was-Rejected $c5Result) {
    Record-Pass "DB rejected duplicate (projectId, key) objective within same project"
} else {
    Record-Fail "DB accepted duplicate (projectId, key) objective -- unique constraint not enforced" $c5Result.Text
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 6: Same key in different projects is accepted (scope is projectId + key)
# All four rows inside one BEGIN/ROLLBACK -- nothing persists.
# ---------------------------------------------------------------------------
Write-Host "[6] Same key in different projects is accepted (cross-project key reuse)"

$c6ProjA = [guid]::NewGuid().ToString()
$c6ProjB = [guid]::NewGuid().ToString()
$c6ObjA  = [guid]::NewGuid().ToString()
$c6ObjB  = [guid]::NewGuid().ToString()
$c6Sql   = @'
BEGIN;
INSERT INTO app.project (id, key, name)
VALUES ('HPROJA', 'hm-c6a-HRKEY', 'Hammer Mut Case 6 Project A');
INSERT INTO app.project (id, key, name)
VALUES ('HPROJB', 'hm-c6b-HRKEY', 'Hammer Mut Case 6 Project B');
INSERT INTO app.objective (id, "projectId", key, title)
VALUES ('HOBJA', 'HPROJA', 'shared-key', 'Shared Key Objective in Project A');
INSERT INTO app.objective (id, "projectId", key, title)
VALUES ('HOBJB', 'HPROJB', 'shared-key', 'Shared Key Objective in Project B');
ROLLBACK;
'@
$c6Sql = $c6Sql.Replace('HPROJA', $c6ProjA).Replace('HPROJB', $c6ProjB)
$c6Sql = $c6Sql.Replace('HOBJA', $c6ObjA).Replace('HOBJB', $c6ObjB)
$c6Sql = $c6Sql.Replace('HRKEY', $runKey)

$c6Result = Invoke-Sql $c6Sql
if (Was-Rejected $c6Result) {
    Record-Fail "DB rejected a cross-project same-key objective -- should have been accepted" $c6Result.Text
} else {
    Record-Pass "DB accepted the same key in two separate projects (scope is (projectId, key), not just key)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host "----------------------------------------"
Write-Host "hammer-mutation  |  PASS: $passCount | SKIP: $skipCount | FAIL: $failCount"
Write-Host ""

if ($failCount -gt 0) { exit 1 } else { exit 0 }
