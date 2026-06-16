param(
    [string]$Phase       = "regression",
    [string]$RunId       = "0",
    [string]$Environment = "dev",
    [string]$ReportsDir  = "target/karate-reports",
    [string]$MetricsDir  = "metrics"
)

# Strip leading @ and normalise to lower-case (e.g. @SanityTest -> sanitest)
$Phase = $Phase.TrimStart('@').ToLower()

# Total scenarios defined across the full project suite (all phases combined)
$TOTAL_DEFINED = 66

# ---------------------------------------------------------------------------
# Parse JSON data block embedded in karate-summary.html
# Karate 2.x standalone does NOT write a separate karate-summary.json.
# All report data is embedded as a <script> JSON block inside the HTML file.
# ---------------------------------------------------------------------------
function Get-KarateSummaryData {
    param([string]$Dir)
    $htmlFile = Get-ChildItem $Dir -Filter "karate-summary.html" -Recurse `
                  -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $htmlFile) { return $null }
    $html      = Get-Content $htmlFile.FullName -Raw -Encoding utf8
    $blocks    = [regex]::Matches($html, '(?s)<script[^>]*>(.*?)</script>')
    $dataBlock = $blocks | Where-Object { $_.Groups[1].Value -match '"summary"' } |
                 Select-Object -First 1
    if (-not $dataBlock) { return $null }
    return $dataBlock.Groups[1].Value | ConvertFrom-Json
}

$summary = Get-KarateSummaryData -Dir $ReportsDir
if (-not $summary) {
    Write-Warning "Could not extract data from karate-summary.html in '$ReportsDir' - skipping metrics."
    exit 0
}

# ---------------------------------------------------------------------------
# Top-level counters
# JSON field names: summary.scenario_passed / scenario_failed / duration_millis
# ---------------------------------------------------------------------------
$passed   = [int]$summary.summary.scenario_passed
$failed   = [int]$summary.summary.scenario_failed
$total    = $passed + $failed
$passRate = if ($total -gt 0) { [math]::Round(($passed / $total) * 100, 2) } else { 0 }
$execSec  = [math]::Round([double]$summary.summary.duration_millis / 1000, 1)
$runDate  = (Get-Date -Format "yyyy-MM-dd")

# Ensure output directories exist
foreach ($dir in @($MetricsDir, "reports")) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
}

# ---------------------------------------------------------------------------
# Append to runs.csv - one row per workflow run
# ---------------------------------------------------------------------------
$runsFile = "$MetricsDir/runs.csv"
if (-not (Test-Path $runsFile)) {
    "date,runId,phase,environment,totalDefined,totalExecuted,passed,failed,passRate,executionTimeSec" |
        Out-File $runsFile -Encoding utf8
}
"$runDate,$RunId,$Phase,$Environment,$TOTAL_DEFINED,$total,$passed,$failed,$passRate,$execSec" |
    Add-Content $runsFile -Encoding utf8

# ---------------------------------------------------------------------------
# Per-module breakdown
# Tags in the embedded JSON include the @ prefix (e.g. "@IntentionalFailure")
# ---------------------------------------------------------------------------
$modulesFile = "$MetricsDir/modules.csv"
if (-not (Test-Path $modulesFile)) {
    "date,runId,phase,module,totalScenarios,passed,failed,defectDensity" |
        Out-File $modulesFile -Encoding utf8
}

$moduleData = @{}

if ($summary.features) {
    foreach ($fr in $summary.features) {
        # relativePath example: "src/test/java/examples/posts/PostCall.feature"
        # Module = second-to-last path segment (e.g. "posts")
        $parts  = ($fr.relativePath -split '/') | Where-Object { $_ -ne '' }
        $module = if ($parts.Count -ge 2) { $parts[-2] } else { "unknown" }

        if (-not $moduleData.ContainsKey($module)) {
            $moduleData[$module] = @{ passed = 0; failed = 0 }
        }

        if ($fr.scenarios) {
            foreach ($sr in $fr.scenarios) {
                $isIntentional = $sr.tags -and ($sr.tags -contains "@IntentionalFailure")
                if (-not $isIntentional -and -not $sr.skipped) {
                    if ($sr.passed) { $moduleData[$module].passed++ }
                    else            { $moduleData[$module].failed++ }
                }
            }
        } else {
            $moduleData[$module].passed += [int]$fr.passedCount
            $moduleData[$module].failed += [int]$fr.failedCount
        }
    }
}

$currentFailingModules = @()
foreach ($mod in ($moduleData.Keys | Sort-Object)) {
    $mp = $moduleData[$mod].passed
    $mf = $moduleData[$mod].failed
    $mt = $mp + $mf
    $dd = if ($mt -gt 0) { [math]::Round($mf / $mt * 100, 2) } else { 0 }
    "$runDate,$RunId,$Phase,$mod,$mt,$mp,$mf,$dd" | Add-Content $modulesFile -Encoding utf8
    if ($mf -gt 0) { $currentFailingModules += $mod }
}

# ---------------------------------------------------------------------------
# Defect leakage detection
# A leakage event = module passed in the previous phase today but fails here.
# ---------------------------------------------------------------------------
$leakageFile = "$MetricsDir/leakage.csv"
if (-not (Test-Path $leakageFile)) {
    "date,runId,fromPhase,toPhase,module,newFailures" | Out-File $leakageFile -Encoding utf8
}

$phaseOrder = @('smoke', 'sanity', 'regression', 'parallel')
$phaseIdx   = $phaseOrder.IndexOf($Phase)

if ($phaseIdx -gt 0 -and (Test-Path $modulesFile)) {
    $prevPhase = $phaseOrder[$phaseIdx - 1]
    try {
        $allModuleRows   = Import-Csv $modulesFile
        $prevGoodModules = $allModuleRows |
            Where-Object { $_.date -eq $runDate -and $_.phase -eq $prevPhase -and [int]$_.failed -eq 0 } |
            Select-Object -ExpandProperty module
        foreach ($mod in $currentFailingModules) {
            if ($prevGoodModules -contains $mod) {
                "$runDate,$RunId,$prevPhase,$Phase,$mod,1" | Add-Content $leakageFile -Encoding utf8
                Write-Host "  [LEAKAGE] '$mod' passed in $prevPhase but failed in $Phase"
            }
        }
    } catch {
        Write-Warning "Leakage comparison skipped: $_"
    }
}

# ---------------------------------------------------------------------------
# Write latest-run.json - consumed by both report generators
# ---------------------------------------------------------------------------
$moduleSummary = @{}
foreach ($mod in $moduleData.Keys) {
    $mp = $moduleData[$mod].passed
    $mf = $moduleData[$mod].failed
    $mt = $mp + $mf
    $moduleSummary[$mod] = [ordered]@{
        passed        = $mp
        failed        = $mf
        total         = $mt
        defectDensity = if ($mt -gt 0) { [math]::Round($mf / $mt * 100, 2) } else { 0 }
    }
}

[ordered]@{
    date           = $runDate
    runId          = $RunId
    phase          = $Phase
    environment    = $Environment
    totalDefined   = $TOTAL_DEFINED
    totalExecuted  = $total
    passed         = $passed
    failed         = $failed
    passRate       = $passRate
    executionSec   = $execSec
    modules        = $moduleSummary
    failingModules = $currentFailingModules
} | ConvertTo-Json -Depth 5 | Out-File "$MetricsDir/latest-run.json" -Encoding utf8

Write-Host ""
Write-Host "=== Metrics Extracted ==="
Write-Host "Phase       : $Phase"
Write-Host "Environment : $Environment"
Write-Host "Executed    : $total"
Write-Host "Passed      : $passed"
Write-Host "Failed      : $failed"
Write-Host "Pass Rate   : $passRate%"
Write-Host "Coverage    : $([math]::Round($total / $TOTAL_DEFINED * 100, 1))% of $TOTAL_DEFINED defined scenarios"
if ($currentFailingModules.Count -gt 0) {
    Write-Host "Failing     : $($currentFailingModules -join ', ')"
}
