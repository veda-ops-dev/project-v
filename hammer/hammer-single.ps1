# hammer-single.ps1 -- Single-module runner
# Runs one named hammer module and prints a clean summary.
#
# Usage:
#   .\hammer\hammer-single.ps1 -Module scope-isolation
#   .\hammer\hammer-single.ps1 -Module mutation -VerboseOutput
#   .\hammer\hammer-single.ps1 -Module core-projects -ConnectionString "postgresql://..."
#
# Module names (without the "hammer-" prefix):
#   scope-isolation
#   mutation
#   polymorphic-boundary
#   core-projects
#
# Exit codes:
#   0 -- module passed
#   1 -- module failed or preflight error
#
# Requires: pwsh (PowerShell 7+)

param(
    [Parameter(Mandatory=$true)][string]$Module,
    [string]$ConnectionString = "postgresql://project_v_app:projectv@localhost:5432/project_v_local",
    [switch]$VerboseOutput
)

$ErrorActionPreference = "Continue"

# ---------------------------------------------------------------------------
# Resolve module file — search core/ then entities/
# ---------------------------------------------------------------------------
$corePath     = Join-Path $PSScriptRoot "core"
$entitiesPath = Join-Path $PSScriptRoot "entities"

$scriptPath = $null
foreach ($searchDir in @($corePath, $entitiesPath)) {
    $candidate = Join-Path $searchDir "hammer-$Module.ps1"
    if (Test-Path $candidate) {
        $scriptPath = $candidate
        break
    }
}

if (-not $scriptPath) {
    Write-Host ""
    Write-Host "  ERROR: module not found -- hammer-$Module.ps1"
    Write-Host ""
    $available = @()
    foreach ($searchDir in @($corePath, $entitiesPath)) {
        $available += Get-ChildItem $searchDir -Filter "hammer-*.ps1" -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Name -replace '^hammer-' -replace '\.ps1$' }
    }
    $available = $available | Sort-Object
    if ($available) {
        Write-Host "  Available modules:"
        foreach ($a in $available) { Write-Host "    $a" }
        Write-Host ""
    }
    exit 1
}

# ---------------------------------------------------------------------------
# Preflight: parse check
# ---------------------------------------------------------------------------
$parseTokens = $null
$parseErrors  = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    $scriptPath, [ref]$parseTokens, [ref]$parseErrors) | Out-Null

if ($parseErrors -and $parseErrors.Count -gt 0) {
    Write-Host ""
    Write-Host "  PREFLIGHT FAIL: parse error in hammer-$Module.ps1"
    Write-Host "  $($parseErrors[0].Message)"
    Write-Host ""
    exit 1
}

# ---------------------------------------------------------------------------
# Execution environment: pwsh (PowerShell 7) required.
# Hammer modules use ?. null-conditional syntax and -AsHashtable, both PS7+.
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
# Tally line parser
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
# Run header
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "========================================"
Write-Host "  PROJECT V -- HAMMER SINGLE"
Write-Host "========================================"
Write-Host "  Module : hammer-$Module"
Write-Host "  PS exe : $psExe"
Write-Host "  Mode   : $(if ($VerboseOutput) { 'verbose' } else { 'summary' })"
Write-Host ""

$start = Get-Date

# ---------------------------------------------------------------------------
# Run the module
# ---------------------------------------------------------------------------
$outputLines = & $psExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
    -File $scriptPath -ConnectionString $ConnectionString 2>&1
$moduleExit  = $LASTEXITCODE
$elapsedMs   = [int]((Get-Date) - $start).TotalMilliseconds

# ---------------------------------------------------------------------------
# Parse tally and print output
# ---------------------------------------------------------------------------
$tally = Parse-TallyLine -lines $outputLines

if ($VerboseOutput -or $moduleExit -ne 0) {
    $outputLines | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
}

$moduleStatus = if ($moduleExit -eq 0) { "PASS" } else { "FAIL" }
$tallyNote    = if ($tally) {
    "PASS: $($tally.Pass) | SKIP: $($tally.Skip) | FAIL: $($tally.Fail)"
} else {
    "tally unavailable"
}

Write-Host "----------------------------------------"
Write-Host "  [$moduleStatus]  hammer-$Module  |  $tallyNote  (${elapsedMs}ms)"
Write-Host "----------------------------------------"
Write-Host ""

if ($moduleExit -ne 0 -and -not $VerboseOutput) {
    Write-Host "  Run with -VerboseOutput to see full case-by-case output."
    Write-Host ""
}

exit $moduleExit
