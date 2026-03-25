# HAMMER MODULE: scope-isolation
# Purpose: ensure strict project isolation at DB level
# Invariants: cross-project FK reference must be rejected by DB
# Assumes: Migration 001 has been applied (app schema + all 15 canonical tables exist)

param(
    [string]$ConnectionString = "postgresql://project_v_app:projectv@localhost:5432/project_v_local"
)

Write-Host "Running hammer: scope-isolation"
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
# Per-run key suffix prevents key collision on repeated runs.
# Setup rows are committed so they serve as FK anchors within this run.
# Project keys must remain lowercase to satisfy project_key_format.
# ---------------------------------------------------------------------------
$runKey = ([guid]::NewGuid().ToString()).Substring(0, 8)
$projA  = [guid]::NewGuid().ToString()
$projB  = [guid]::NewGuid().ToString()
$objA   = [guid]::NewGuid().ToString()

Write-Host "  Setup: creating Project A, Project B, Objective A (run=$runKey)..."

$setupSql = @'
INSERT INTO app.project (id, key, name)
VALUES ('HPROJA', 'hsi-proja-HRKEY', 'Hammer Scope Project A');

INSERT INTO app.project (id, key, name)
VALUES ('HPROJB', 'hsi-projb-HRKEY', 'Hammer Scope Project B');

INSERT INTO app.objective (id, "projectId", key, title)
VALUES ('HOBJA', 'HPROJA', 'hsi-obj-HRKEY', 'Hammer Scope Objective A');
'@
$setupSql = $setupSql.Replace('HPROJA', $projA).Replace('HPROJB', $projB)
$setupSql = $setupSql.Replace('HOBJA', $objA).Replace('HRKEY', $runKey)

$setupResult = Invoke-Sql $setupSql
if (Was-Rejected $setupResult) {
    Write-Host ""
    Write-Host "FAIL: setup failed -- cannot continue."
    Write-Host "      psql output: $($setupResult.Text)"
    exit 1
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 1: Cross-project initiative insert must be rejected
# initiative.projectId = Project B, but objectiveId belongs to Project A.
# The DB constraint enforcing same-project objectiveId must fire.
# Wrapped in BEGIN/ROLLBACK so no row survives regardless of outcome.
# ---------------------------------------------------------------------------
Write-Host "[1] Cross-project initiative insert rejected (projectId=B, objectiveId=A)"

$initId = [guid]::NewGuid().ToString()

$c1Sql = @'
BEGIN;
INSERT INTO app.initiative (id, "projectId", "objectiveId", key, title)
VALUES ('HINITID', 'HPROJB', 'HOBJA', 'hsi-init-bad-HRKEY', 'Invalid Cross-Project Initiative');
ROLLBACK;
'@
$c1Sql = $c1Sql.Replace('HINITID', $initId).Replace('HPROJB', $projB)
$c1Sql = $c1Sql.Replace('HOBJA', $objA).Replace('HRKEY', $runKey)

$c1Result = Invoke-Sql $c1Sql
if (Was-Rejected $c1Result) {
    Record-Pass "DB rejected cross-project initiative insert (same-project constraint enforced)"
} else {
    Record-Fail "DB accepted invalid cross-project insert -- constraint NOT enforced" $c1Result.Text
}

Write-Host ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host "----------------------------------------"
Write-Host "hammer-scope-isolation  |  PASS: $passCount | SKIP: $skipCount | FAIL: $failCount"
Write-Host ""

if ($failCount -gt 0) { exit 1 } else { exit 0 }
