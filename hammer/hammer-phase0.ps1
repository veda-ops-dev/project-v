# hammer-phase0.ps1 -- Phase 0 coordinator
# Runs all Phase 0 hammer modules in order and reports a combined summary.
#
# Usage:
#   .\hammer\hammer-phase0.ps1
#   .\hammer\hammer-phase0.ps1 -ConnectionString "postgresql://user:pass@host:5432/db"
#   .\hammer\hammer-phase0.ps1 -VerboseOutput
#
# Exit codes:
#   0 -- all modules passed
#   1 -- one or more modules failed

param(
    [string]$ConnectionString = "postgresql://project_v_app:projectv@localhost:5432/project_v_local",
    [switch]$VerboseOutput
)

$ErrorActionPreference = "Continue"

# ---------------------------------------------------------------------------
# Modules to run in order
# ---------------------------------------------------------------------------
$moduleDir = Join-Path $PSScriptRoot "core"
$modules   = @(
    "hammer-scope-isolation",
    "hammer-mutation",
    "hammer-polymorphic-boundary"
)

# ---------------------------------------------------------------------------
# Preflight: verify all module files exist and parse cleanly
# ---------------------------------------------------------------------------
$preflightFailed = $false

foreach ($name in $modules) {
    $scriptPath = Join-Path $moduleDir "$name.ps1"

    if (-not (Test-Path $scriptPath)) {
        Write-Host "  PREFLIGHT FAIL: $name.ps1 not found at $scriptPath"
        $preflightFailed = $true
        continue
    }

    $parseTokens = $null
    $parseErrors  = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $scriptPath, [ref]$parseTokens, [ref]$parseErrors) | Out-Null

    if ($parseErrors -and $parseErrors.Count -gt 0) {
        Write-Host "  PREFLIGHT FAIL: parse error in $name.ps1 -- $($parseErrors[0].Message)"
        $preflightFailed = $true
    }
}

if ($preflightFailed) {
    Write-Host ""
    Write-Host "  Preflight failed. Correct errors above before running hammer."
    Write-Host ""
    exit 1
}

# ---------------------------------------------------------------------------
# Per-module result tracking
# ---------------------------------------------------------------------------
$moduleResults = @()

# ---------------------------------------------------------------------------
# Tally line parser
# Matches: "hammer-<n>  |  PASS: N | SKIP: N | FAIL: N"
# Returns a hashtable with Pass/Skip/Fail keys, or $null if no match.
# ---------------------------------------------------------------------------
function Parse-TallyLine($lines) {
    foreach ($line in $lines) {
        if ($line -match 'PASS:\s*(\d+).*SKIP:\s*(\d+).*FAIL:\s*(\d+)') {
            return @{ Pass = [int]$Matches[1]; Skip = [int]$Matches[2]; Fail = [int]$Matches[3] }
        }
    }
    return $null
}

# ---------------------------------------------------------------------------
# Execution environment: pwsh (PowerShell 7) required.
# Hammer modules use ?. null-conditional syntax and -AsHashtable, both PS7+.
# No fallback to powershell (PS5) — it will silently fail to parse modules.
# ---------------------------------------------------------------------------
$pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $pwshCmd) {
    Write-Host ""
    Write-Host "  ERROR: pwsh (PowerShell 7) not found."
    Write-Host "  Hammer modules require PowerShell 7+. Install pwsh and retry."
    Write-Host ""
    exit 1
}
$psExe = "pwsh"

# ---------------------------------------------------------------------------
# Run header
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "========================================"
Write-Host "  PROJECT V -- PHASE 0 HAMMER"
Write-Host "========================================"
Write-Host "  PS exe  : $psExe"
Write-Host "  Mode    : $(if ($VerboseOutput) { 'verbose' } else { 'summary' })"
Write-Host ""

$overallStart = Get-Date

# ---------------------------------------------------------------------------
# Run each module
# ---------------------------------------------------------------------------
foreach ($name in $modules) {
    $scriptPath  = Join-Path $moduleDir "$name.ps1"
    $moduleStart = Get-Date

    # Run module as a subprocess for clean isolation.
    $outputLines = & $psExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
        -File $scriptPath -ConnectionString $ConnectionString 2>&1
    $moduleExit  = $LASTEXITCODE
    $moduleMs    = [int]((Get-Date) - $moduleStart).TotalMilliseconds

    # Parse the tally line from module output.
    $tally = Parse-TallyLine -lines $outputLines

    if ($tally) {
        $moduleResults += [PSCustomObject]@{
            Name     = $name
            ExitCode = $moduleExit
            Pass     = $tally.Pass
            Skip     = $tally.Skip
            Fail     = $tally.Fail
            Parsed   = $true
            Ms       = $moduleMs
            Lines    = $outputLines
        }
    } else {
        Write-Host "  WARNING: could not parse tally line from $name output."
        $moduleResults += [PSCustomObject]@{
            Name     = $name
            ExitCode = $moduleExit
            Pass     = 0
            Skip     = 0
            Fail     = 0
            Parsed   = $false
            Ms       = $moduleMs
            Lines    = $outputLines
        }
    }

    $moduleStatus = if ($moduleExit -eq 0) { "PASS" } else { "FAIL" }
    $tallyNote    = if ($tally) {
        "PASS: $($tally.Pass) | SKIP: $($tally.Skip) | FAIL: $($tally.Fail)"
    } else {
        "tally unavailable"
    }

    Write-Host ("  [{0,-4}]  {1,-36}  {2}  ({3}ms)" -f $moduleStatus, $name, $tallyNote, $moduleMs)

    # In verbose mode, echo all module output indented.
    if ($VerboseOutput) {
        Write-Host ""
        $outputLines | ForEach-Object { Write-Host "         $_" }
        Write-Host ""
    } elseif ($moduleExit -ne 0) {
        # In summary mode, always show detail for failed modules.
        Write-Host ""
        $outputLines | ForEach-Object { Write-Host "         $_" }
        Write-Host ""
    }
}

# ---------------------------------------------------------------------------
# Overall summary
# ---------------------------------------------------------------------------
$totalMs     = [int]((Get-Date) - $overallStart).TotalMilliseconds
$totalPass   = 0
$totalSkip   = 0
$totalFail   = 0
$anyUnparsed = $false

foreach ($r in $moduleResults) {
    if ($r.Parsed) {
        $totalPass += $r.Pass
        $totalSkip += $r.Skip
        $totalFail += $r.Fail
    } else {
        $anyUnparsed = $true
    }
}

Write-Host ""
Write-Host "----------------------------------------"
Write-Host "  TOTALS  |  PASS: $totalPass | SKIP: $totalSkip | FAIL: $totalFail  (${totalMs}ms)"
Write-Host "----------------------------------------"

if ($anyUnparsed) {
    Write-Host ""
    Write-Host "  NOTE: one or more modules did not emit a parseable tally line."
    Write-Host "        Aggregated counts reflect only parsed modules."
}

Write-Host ""

$overallFailed = ($moduleResults | Where-Object { $_.ExitCode -ne 0 }).Count

if ($overallFailed -eq 0) {
    Write-Host "  ALL MODULES PASSED."
    Write-Host ""
    exit 0
} else {
    Write-Host "  $overallFailed MODULE(S) FAILED."
    if (-not $VerboseOutput) {
        Write-Host "  Run with -VerboseOutput to see full case-by-case output."
    }
    Write-Host ""
    exit 1
}