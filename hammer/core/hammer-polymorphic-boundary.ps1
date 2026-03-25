# HAMMER MODULE: polymorphic-boundary
# Purpose: verify DB-level enforcement of polymorphic entityType vocabulary,
#          and honestly document where same-project / existence enforcement
#          is application-layer responsibility only.
# Invariants: CHECK constraints on entityType fields in Dependency, EvidenceLink,
#             Handoff, StatusHistory -- vocabulary only, not existence or same-project.
# Assumes: Migration 001 has been applied (app schema + all 15 canonical tables exist)

param(
    [string]$ConnectionString = "postgresql://project_v_app:projectv@localhost:5432/project_v_local"
)

Write-Host "Running hammer: polymorphic-boundary"
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
# Anchor project, one objective, one initiative -- committed so they survive
# as valid FK targets across subtests within this run.
# All subtest rows are wrapped in BEGIN/ROLLBACK and do not persist.
# ---------------------------------------------------------------------------
$runKey = ([guid]::NewGuid().ToString()).Substring(0, 8)
$proj   = [guid]::NewGuid().ToString()
$objId  = [guid]::NewGuid().ToString()
$initId = [guid]::NewGuid().ToString()

Write-Host "  Setup: creating anchor project, objective, initiative (run=$runKey)..."

$setupSql = @'
INSERT INTO app.project (id, key, name)
VALUES ('HPROJ', 'hpb-HRKEY', 'Hammer Polymorphic Boundary Project');

INSERT INTO app.objective (id, "projectId", key, title)
VALUES ('HOBJID', 'HPROJ', 'hpb-obj-HRKEY', 'HPB Seed Objective');

INSERT INTO app.initiative (id, "projectId", key, title)
VALUES ('HINITID', 'HPROJ', 'hpb-init-HRKEY', 'HPB Seed Initiative');
'@
$setupSql = $setupSql.Replace('HPROJ', $proj).Replace('HOBJID', $objId)
$setupSql = $setupSql.Replace('HINITID', $initId).Replace('HRKEY', $runKey)

$setupResult = Invoke-Sql $setupSql
if (Was-Rejected $setupResult) {
    Write-Host ""
    Write-Host "FAIL: setup failed -- cannot continue."
    Write-Host "      psql output: $($setupResult.Text)"
    exit 1
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 1: Invalid entityType rejected -- app.dependency
# Allowed sourceEntityType: objective | initiative | work_item | handoff
# Allowed targetEntityType: objective | initiative | work_item | handoff
# 'project' is NOT in the allowed set for dependency targets.
# ---------------------------------------------------------------------------
Write-Host "[1a] Invalid sourceEntityType rejected (app.dependency sourceEntityType='banana')"

$d1Id  = [guid]::NewGuid().ToString()
$d1Sql = @'
BEGIN;
INSERT INTO app.dependency (id, "projectId", "sourceEntityType", "sourceEntityId",
                            "targetEntityType", "targetEntityId", "dependencyType", status)
VALUES ('HID1', 'HPROJ', 'banana', 'HOBJID',
        'initiative', 'HINITID', 'blocks', 'active');
ROLLBACK;
'@
$d1Sql = $d1Sql.Replace('HID1', $d1Id).Replace('HPROJ', $proj)
$d1Sql = $d1Sql.Replace('HOBJID', $objId).Replace('HINITID', $initId)

$d1Result = Invoke-Sql $d1Sql
if (Was-Rejected $d1Result) {
    Record-Pass "DB rejected dependency with invalid sourceEntityType 'banana'"
} else {
    Record-Fail "DB accepted dependency with invalid sourceEntityType 'banana'" $d1Result.Text
}

Write-Host ""
Write-Host "[1b] Invalid targetEntityType rejected (app.dependency targetEntityType='project')"

$d2Id  = [guid]::NewGuid().ToString()
$d2Sql = @'
BEGIN;
INSERT INTO app.dependency (id, "projectId", "sourceEntityType", "sourceEntityId",
                            "targetEntityType", "targetEntityId", "dependencyType", status)
VALUES ('HID1', 'HPROJ', 'objective', 'HOBJID',
        'project', 'HPROJ', 'blocks', 'active');
ROLLBACK;
'@
$d2Sql = $d2Sql.Replace('HID1', $d2Id).Replace('HPROJ', $proj).Replace('HOBJID', $objId)

$d2Result = Invoke-Sql $d2Sql
if (Was-Rejected $d2Result) {
    Record-Pass "DB rejected dependency with invalid targetEntityType 'project' (not in allowed set)"
} else {
    Record-Fail "DB accepted dependency with invalid targetEntityType 'project'" $d2Result.Text
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 2: Invalid entityType rejected -- app.evidence_link
# Allowed sourceEntityType: objective | initiative | work_item | handoff |
#                           decision_record | research_doc
# ---------------------------------------------------------------------------
Write-Host "[2] Invalid sourceEntityType rejected (app.evidence_link sourceEntityType='spaceship')"

$elId  = [guid]::NewGuid().ToString()
$elSql = @'
BEGIN;
INSERT INTO app.evidence_link (id, "projectId", "sourceEntityType", "sourceEntityId",
                               "evidenceType", "targetLocator")
VALUES ('HID1', 'HPROJ', 'spaceship', 'HOBJID',
        'document', 'https://example.com/evidence');
ROLLBACK;
'@
$elSql = $elSql.Replace('HID1', $elId).Replace('HPROJ', $proj).Replace('HOBJID', $objId)

$elResult = Invoke-Sql $elSql
if (Was-Rejected $elResult) {
    Record-Pass "DB rejected evidence_link with invalid sourceEntityType 'spaceship'"
} else {
    Record-Fail "DB accepted evidence_link with invalid sourceEntityType 'spaceship'" $elResult.Text
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 3: Invalid entityType rejected -- app.handoff
# Allowed sourceEntityType: objective | initiative | work_item
# 'audit_run' is explicitly NOT in the handoff allowed set.
# ---------------------------------------------------------------------------
Write-Host "[3] Invalid sourceEntityType rejected (app.handoff sourceEntityType='audit_run')"

$hoId  = [guid]::NewGuid().ToString()
$hoSql = @'
BEGIN;
INSERT INTO app.handoff (id, "projectId", "sourceEntityType", "sourceEntityId",
                         "targetSystem", "handoffType", status)
VALUES ('HID1', 'HPROJ', 'audit_run', 'HOBJID',
        'veda', 'execution', 'proposed');
ROLLBACK;
'@
$hoSql = $hoSql.Replace('HID1', $hoId).Replace('HPROJ', $proj).Replace('HOBJID', $objId)

$hoResult = Invoke-Sql $hoSql
if (Was-Rejected $hoResult) {
    Record-Pass "DB rejected handoff with invalid sourceEntityType 'audit_run'"
} else {
    Record-Fail "DB accepted handoff with invalid sourceEntityType 'audit_run'" $hoResult.Text
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 4: Invalid entityType rejected -- app.status_history
# Allowed entityType: project | objective | initiative | work_item |
#                    handoff | decision_record | audit_run
# ---------------------------------------------------------------------------
Write-Host "[4] Invalid entityType rejected (app.status_history entityType='flux_capacitor')"

$shId  = [guid]::NewGuid().ToString()
$shSql = @'
BEGIN;
INSERT INTO app.status_history (id, "projectId", "entityType", "entityId",
                                "newStatus", actor)
VALUES ('HID1', 'HPROJ', 'flux_capacitor', 'HOBJID',
        'active', 'hammer');
ROLLBACK;
'@
$shSql = $shSql.Replace('HID1', $shId).Replace('HPROJ', $proj).Replace('HOBJID', $objId)

$shResult = Invoke-Sql $shSql
if (Was-Rejected $shResult) {
    Record-Pass "DB rejected status_history with invalid entityType 'flux_capacitor'"
} else {
    Record-Fail "DB accepted status_history with invalid entityType 'flux_capacitor'" $shResult.Text
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 5: Valid entityType values accepted
# Two representative spot-checks confirming the CHECK allows correct values.
# ---------------------------------------------------------------------------
Write-Host "[5a] Valid entityType accepted (app.status_history entityType='objective')"

$sh2Id  = [guid]::NewGuid().ToString()
$sh2Sql = @'
BEGIN;
INSERT INTO app.status_history (id, "projectId", "entityType", "entityId",
                                "newStatus", actor)
VALUES ('HID1', 'HPROJ', 'objective', 'HOBJID',
        'active', 'hammer');
ROLLBACK;
'@
$sh2Sql = $sh2Sql.Replace('HID1', $sh2Id).Replace('HPROJ', $proj).Replace('HOBJID', $objId)

$sh2Result = Invoke-Sql $sh2Sql
if (Was-Rejected $sh2Result) {
    Record-Fail "DB rejected status_history with valid entityType 'objective' -- CHECK too strict or insert malformed" $sh2Result.Text
} else {
    Record-Pass "DB accepted status_history with valid entityType 'objective'"
}

Write-Host ""
Write-Host "[5b] Valid sourceEntityType accepted (app.handoff sourceEntityType='initiative')"

$ho2Id  = [guid]::NewGuid().ToString()
$ho2Sql = @'
BEGIN;
INSERT INTO app.handoff (id, "projectId", "sourceEntityType", "sourceEntityId",
                         "targetSystem", "handoffType", status)
VALUES ('HID1', 'HPROJ', 'initiative', 'HINITID',
        'veda', 'execution', 'proposed');
ROLLBACK;
'@
$ho2Sql = $ho2Sql.Replace('HID1', $ho2Id).Replace('HPROJ', $proj).Replace('HINITID', $initId)

$ho2Result = Invoke-Sql $ho2Sql
if (Was-Rejected $ho2Result) {
    Record-Fail "DB rejected handoff with valid sourceEntityType 'initiative' -- CHECK too strict or insert malformed" $ho2Result.Text
} else {
    Record-Pass "DB accepted handoff with valid sourceEntityType 'initiative'"
}

Write-Host ""

# ---------------------------------------------------------------------------
# CASE 6: Honest boundary -- DB does NOT enforce entityId existence or same-project
#
# The DB enforces: entityType vocabulary (cases 1-4 above).
# The DB does NOT enforce:
#   - that entityId actually exists in any table
#   - that entityId belongs to the same project as the owning row
#
# These are intentional application-layer responsibilities per:
#   docs/architecture/data/polymorphic-reference-enforcement.md
#
# This case inserts a status_history row with a valid entityType but a
# completely fabricated entityId that has no matching row anywhere.
# Expected: DB accepts it (no FK constraint exists for polymorphic refs).
# Reported as INFO only -- does not affect PASS/SKIP/FAIL counts.
# ---------------------------------------------------------------------------
Write-Host "[6] Honest boundary -- DB does NOT enforce entityId existence or same-project"

$sh3Id    = [guid]::NewGuid().ToString()
$phantomId = [guid]::NewGuid().ToString()
$sh3Sql   = @'
BEGIN;
INSERT INTO app.status_history (id, "projectId", "entityType", "entityId",
                                "newStatus", actor)
VALUES ('HID1', 'HPROJ', 'objective', 'HPHANTOM',
        'active', 'hammer');
ROLLBACK;
'@
$sh3Sql = $sh3Sql.Replace('HID1', $sh3Id).Replace('HPROJ', $proj).Replace('HPHANTOM', $phantomId)

$sh3Result = Invoke-Sql $sh3Sql
if (Was-Rejected $sh3Result) {
    Record-Info "DB rejected status_history pointing at a phantom entityId -- UNEXPECTED. A DB-level FK may have been added. Review before proceeding."
    Record-Info "psql output: $($sh3Result.Text)"
} else {
    Record-Info "DB accepted status_history pointing at a phantom entityId -- EXPECTED. Existence and same-project enforcement is application-layer responsibility only (polymorphic-reference-enforcement.md)."
}

Write-Host ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host "----------------------------------------"
Write-Host "hammer-polymorphic-boundary  |  PASS: $passCount | SKIP: $skipCount | FAIL: $failCount"
Write-Host "  Note: case [6] is INFO only and does not affect counts."
Write-Host ""

if ($failCount -gt 0) { exit 1 } else { exit 0 }
