param(
    [string]$MetricsDir     = "metrics",
    [string]$ReportsDir     = "reports",
    [int]$GreenThreshold    = 95,
    [int]$AmberThreshold    = 80
)

if (-not (Test-Path $ReportsDir)) { New-Item -ItemType Directory -Force $ReportsDir | Out-Null }

$latestFile = "$MetricsDir/latest-run.json"
if (-not (Test-Path $latestFile)) {
    Write-Warning "latest-run.json not found in '$MetricsDir' - run extract-metrics.ps1 first."
    exit 0
}

$run = Get-Content $latestFile -Raw | ConvertFrom-Json

# ---------------------------------------------------------------------------
# Portable HTML entity encoding (works on PS 5.1 and PS 7/Linux)
# ---------------------------------------------------------------------------
function Encode-Html {
    param([string]$s)
    $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;')
}

# ---------------------------------------------------------------------------
# Shared calculations (used by both tabs)
# ---------------------------------------------------------------------------
$coveragePct = if ($run.totalDefined -gt 0) {
    [math]::Round($run.totalExecuted / $run.totalDefined * 100, 1)
} else { 0 }

$health = if ([double]$run.passRate -ge $GreenThreshold) { "GREEN" }
          elseif ([double]$run.passRate -ge $AmberThreshold) { "AMBER" }
          else { "RED" }

$healthLabel = switch ($health) {
    "GREEN" { "GREEN - HEALTHY"  }
    "AMBER" { "AMBER - AT RISK"  }
    "RED"   { "RED - CRITICAL"   }
}

$healthNote = switch ($health) {
    "GREEN" { "Quality gate <strong>PASSED</strong>. Pass rate meets the &ge; $GreenThreshold% threshold for deployment approval." }
    "AMBER" { "Quality gate <strong>WARNING</strong>. Pass rate ($($run.passRate)%) is below $GreenThreshold%. Investigation recommended before proceeding." }
    "RED"   { "Quality gate <strong>FAILED</strong>. Pass rate ($($run.passRate)%) is critically below $AmberThreshold%. Do not deploy." }
}

$healthColor = switch ($health) {
    "GREEN" { "#16a34a" }
    "AMBER" { "#d97706" }
    "RED"   { "#dc2626" }
}

$healthBg = switch ($health) {
    "GREEN" { "#f0fdf4" }
    "AMBER" { "#fffbeb" }
    "RED"   { "#fef2f2" }
}

# Trend vs previous run of same phase
$trendText = ""
if (Test-Path "$MetricsDir/runs.csv") {
    try {
        $allRuns = Import-Csv "$MetricsDir/runs.csv"
        $prevRun = $allRuns |
            Where-Object { $_.phase -eq $run.phase -and $_.runId -ne $run.runId.ToString() } |
            Select-Object -Last 1
        if ($prevRun) {
            $prevRate = [double]$prevRun.passRate
            $delta    = [math]::Round([double]$run.passRate - $prevRate, 2)
            $arrow    = if ($delta -ge 0) { "&#8593;" } else { "&#8595;" }
            $color    = if ($delta -ge 0) { "#16a34a" } else { "#dc2626" }
            $trendText = "<span style='color:$color'>$arrow $([math]::Abs($delta))pp</span> vs last $($run.phase) run (was $prevRate%)"
        }
    } catch { }
}

# Leakage events
$leakageEvents = @()
$leakageCount = 0
if (Test-Path "$MetricsDir/leakage.csv") {
    try {
        $leakageEvents = @(Import-Csv "$MetricsDir/leakage.csv" |
            Where-Object { $_.date -eq $run.date -and $_.toPhase -eq $run.phase })
        $leakageCount = $leakageEvents.Count
    } catch { }
}

# Module rows for current run (IT tab)
$moduleRows = @()
if (Test-Path "$MetricsDir/modules.csv") {
    try {
        $moduleRows = @(Import-Csv "$MetricsDir/modules.csv" |
            Where-Object { $_.date -eq $run.date -and $_.phase -eq $run.phase -and $_.runId -eq $run.runId.ToString() -and [int]$_.totalScenarios -gt 0 } |
            Sort-Object { [double]$_.defectDensity } -Descending)
    } catch { }
}

# Risk modules (stakeholder tab)
$riskModules = @($moduleRows | Where-Object { [int]$_.failed -gt 0 })

# All phases run today - latest per phase (stakeholder tab)
$allTodayRuns = @()
if (Test-Path "$MetricsDir/runs.csv") {
    try {
        $todayRuns     = Import-Csv "$MetricsDir/runs.csv" | Where-Object { $_.date -eq $run.date }
        $phaseOrder    = @('smoke','sanity','regression','parallel')
        $latestPerPhase = $todayRuns |
            Group-Object phase |
            ForEach-Object { $_.Group | Sort-Object { [int]$_.runId } | Select-Object -Last 1 }
        $allTodayRuns  = @($latestPerPhase | Sort-Object { $phaseOrder.IndexOf($_.phase) })
    } catch { }
}
if ($allTodayRuns.Count -eq 0) {
    $allTodayRuns = @([PSCustomObject]@{ phase = $run.phase; totalExecuted = $run.totalExecuted; passRate = $run.passRate })
}

# 7-day trend
$weekTrend = @()
if (Test-Path "$MetricsDir/runs.csv") {
    try {
        $cutoff    = (Get-Date).AddDays(-7).ToString("yyyy-MM-dd")
        $weekTrend = @(Import-Csv "$MetricsDir/runs.csv" |
            Where-Object { $_.phase -eq $run.phase -and $_.date -ge $cutoff } |
            Sort-Object date)
    } catch { }
}

# Failed scenario detail from karate-summary.html
$failedScenarios = @()
$htmlFile = Get-ChildItem "target/karate-reports" -Filter "karate-summary.html" `
              -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($htmlFile) {
    try {
        $html      = Get-Content $htmlFile.FullName -Raw -Encoding utf8
        $blocks    = [regex]::Matches($html, '(?s)<script[^>]*>(.*?)</script>')
        $dataBlock = $blocks | Where-Object { $_.Groups[1].Value -match '"summary"' } |
                     Select-Object -First 1
        if ($dataBlock) {
            $karateData = $dataBlock.Groups[1].Value | ConvertFrom-Json
            if ($karateData.features) {
                foreach ($fr in $karateData.features) {
                    if ($fr.scenarios) {
                        foreach ($sr in $fr.scenarios) {
                            if (-not $sr.passed -and -not $sr.skipped) {
                                $tagStr = if ($sr.tags -and $sr.tags.Count -gt 0) {
                                    "<span class='tag'>$($sr.tags -join '</span> <span class=''tag''>')</span>"
                                } else { "" }
                                $failedScenarios += [PSCustomObject]@{
                                    name    = Encode-Html $sr.name
                                    path    = Encode-Html $fr.relativePath
                                    tagHtml = $tagStr
                                }
                            }
                        }
                    }
                }
            }
        }
    } catch { }
}

# ---------------------------------------------------------------------------
# Helper: build an HTML table from an array of row arrays
# ---------------------------------------------------------------------------
function Build-HtmlTable {
    param([string[]]$Headers, [string[][]]$Rows, [string]$Id = "")
    $idAttr = if ($Id) { " id='$Id'" } else { "" }
    $th = ($Headers | ForEach-Object { "<th>$_</th>" }) -join ""
    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("<table$idAttr><thead><tr>$th</tr></thead><tbody>")
    foreach ($row in $Rows) {
        $td = ($row | ForEach-Object { "<td>$_</td>" }) -join ""
        $null = $sb.AppendLine("<tr>$td</tr>")
    }
    $null = $sb.AppendLine("</tbody></table>")
    return $sb.ToString()
}

# ---------------------------------------------------------------------------
# Executive tab content
# ---------------------------------------------------------------------------
$stagingStatus = if ([double]$run.passRate -ge $AmberThreshold) { "<span class='pass'>PASS</span>" } else { "<span class='fail'>HOLD</span>" }
$prodStatus    = if ([double]$run.passRate -ge $GreenThreshold)  { "<span class='pass'>PASS</span>" } else { "<span class='fail'>HOLD</span>" }

$phaseRows = @()
foreach ($pr in $allTodayRuns) {
    $gs = if ([double]$pr.passRate -ge $GreenThreshold) { "<span class='pass'>PASS</span>" }
          elseif ([double]$pr.passRate -ge $AmberThreshold) { "<span class='warn'>WARN</span>" }
          else { "<span class='fail'>FAIL</span>" }
    $phaseRows += ,@($pr.phase.ToUpper(), $pr.totalExecuted, "$($pr.passRate)%", $gs)
}

$trendRows = @()
if ($weekTrend.Count -gt 0) {
    foreach ($wt in $weekTrend) { $trendRows += ,@($wt.date, "$($wt.passRate)%") }
} else {
    $trendRows += ,@($run.date, "$($run.passRate)%")
    $trendRows += ,@("<em>More data available after subsequent runs</em>", "-")
}

$riskHtml = if ($riskModules.Count -gt 0) {
    $items = $riskModules | ForEach-Object {
        $risk = if ([int]$_.failed -ge 3) { "HIGH" } elseif ([int]$_.failed -ge 2) { "MEDIUM" } else { "LOW" }
        $riskColor = if ($risk -eq "HIGH") { "#dc2626" } elseif ($risk -eq "MEDIUM") { "#d97706" } else { "#2563eb" }
        "<li><strong>$($_.module)</strong> area: $($_.failed) failure(s) &mdash; <span style='color:$riskColor;font-weight:bold'>$risk risk</span></li>"
    }
    "<ul>$($items -join '')</ul><p class='note'>One known expected failure in the posts area is excluded from risk scoring.</p>"
} else {
    "<p class='ok'>No risk areas identified. All functional areas passed.</p>"
}

$leakageExecHtml = if ($leakageCount -gt 0) {
    "<p><strong>$leakageCount issue(s) were not caught in the previous testing phase</strong> and only surfaced at the $($run.phase.ToUpper()) stage.</p><p class='action'>Action Required: Review upstream test coverage to close the detection gap before the next release cycle.</p>"
} else {
    "<p class='ok'>No defect leakage detected. All failures were identified at or before the $($run.phase.ToUpper()) phase.</p>"
}

$execTab = @"
<div class="section">
  <div class="health-badge" style="background:$healthColor">$healthLabel</div>
  <p class="health-note" style="background:$healthBg;border-left:4px solid $healthColor">$healthNote</p>
</div>

<div class="section">
  <h2>Key Indicators</h2>
  $(Build-HtmlTable -Headers @("Indicator","Value") -Rows @(
    ,@("Automation Pass Rate", "<strong>$($run.passRate)%</strong>"),
    ,@("Test Execution Coverage", "$coveragePct% of full suite"),
    ,@("Defect Leakage Events", $leakageCount),
    ,@("Risk Areas", "$($riskModules.Count) area(s) with failures")
  ))
</div>

<div class="section">
  <h2>Phase Coverage</h2>
  $(Build-HtmlTable -Headers @("Phase","Scenarios Run","Pass Rate","Gate Status") -Rows $phaseRows)
</div>

<div class="section">
  <h2>Risk Areas</h2>
  $riskHtml
</div>

<div class="section">
  <h2>Defect Leakage</h2>
  $leakageExecHtml
</div>

<div class="section">
  <h2>7-Day Pass Rate Trend ($($run.phase.ToUpper()) phase)</h2>
  $(Build-HtmlTable -Headers @("Date","Pass Rate") -Rows $trendRows)
</div>

<div class="section">
  <h2>Milestone Gates</h2>
  $(Build-HtmlTable -Headers @("Gate","Threshold","Current","Status") -Rows @(
    ,@("Deploy to Staging",    "&ge; $AmberThreshold%", "$($run.passRate)%", $stagingStatus),
    ,@("Deploy to Production", "&ge; $GreenThreshold%", "$($run.passRate)%", $prodStatus)
  ))
</div>

<p class="footer">This report is auto-generated from CI test execution data. For technical detail see the IT Technical Report tab.</p>
"@

# ---------------------------------------------------------------------------
# IT Technical tab content
# ---------------------------------------------------------------------------
$moduleTableRows = @()
foreach ($row in $moduleRows) {
    $warn = if ([int]$row.failed -gt 0) { " <span class='warn-badge'>WARN</span>" } else { "" }
    $moduleTableRows += ,@("$($row.module)$warn", $row.totalScenarios, $row.passed, $row.failed, "$($row.defectDensity)%")
}
if ($moduleTableRows.Count -eq 0) { $moduleTableRows += ,@("<em>No module data available</em>","-","-","-","-") }

$leakITHtml = if ($leakageEvents.Count -gt 0) {
    $items = $leakageEvents | ForEach-Object {
        "<li>Module <code>$($_.module)</code> &mdash; passed in <strong>$($_.fromPhase.ToUpper())</strong>, failed in <strong>$($_.toPhase.ToUpper())</strong></li>"
    }
    "<p><strong>$($leakageEvents.Count) module(s) passed upstream but failed in $($run.phase.ToUpper()):</strong></p><ul>$($items -join '')</ul><p class='action'>Action: Add or strengthen $($run.phase) test coverage for the modules listed above.</p>"
} else {
    "<p class='ok'>No defect leakage detected for this run.</p>"
}

$failedHtml = if ($failedScenarios.Count -gt 0) {
    $items = $failedScenarios | ForEach-Object {
        "<div class='failed-scenario'><div class='scenario-name'>$($_.name)</div><div class='scenario-path'><code>$($_.path)</code></div>$(if($_.tagHtml){"<div class='scenario-tags'>$($_.tagHtml)</div>"})</div>"
    }
    $items -join ""
} else {
    "<p class='ok'>All scenarios passed.</p>"
}

$summaryRows = @(
    ,@("Total Scenarios Executed", $run.totalExecuted),
    ,@("Passed", $run.passed),
    ,@("Failed", $run.failed),
    ,@("Automation Pass Rate", "<strong>$($run.passRate)%</strong>"),
    ,@("Test Execution Coverage", "$coveragePct% of $($run.totalDefined) defined scenarios"),
    ,@("Execution Time", "$($run.executionSec)s"),
    ,@("Defect Leakage Events", $leakageCount)
)
if ($trendText) { $summaryRows += ,@("Trend", $trendText) }

$itTab = @"
<div class="section">
  <h2>Summary</h2>
  $(Build-HtmlTable -Headers @("Metric","Value") -Rows $summaryRows)
</div>

<div class="section">
  <h2>Module Breakdown &mdash; Defect Density</h2>
  $(Build-HtmlTable -Headers @("Module","Executed","Passed","Failed","Defect Density") -Rows $moduleTableRows)
  <p class="note"><strong>Note:</strong> <code>posts</code> module excludes <code>@IntentionalFailure</code> scenarios (PostCall TestCase2) from defect density.</p>
</div>

<div class="section">
  <h2>Defect Leakage</h2>
  $leakITHtml
</div>

<div class="section">
  <h2>Failed Scenarios</h2>
  $failedHtml
</div>

<div class="section">
  <h2>Artifacts</h2>
  <ul>
    <li>HTML Summary: <code>target/karate-reports/karate-summary.html</code></li>
    <li>Execution Timeline: <code>target/karate-reports/karate-timeline.html</code></li>
    <li>Per-feature Reports: <code>target/karate-reports/feature-html/</code></li>
  </ul>
</div>

<p class="footer">Generated by scripts/generate-combined-report.ps1</p>
"@

# ---------------------------------------------------------------------------
# Assemble full HTML page
# ---------------------------------------------------------------------------
$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Quality Report &mdash; $($run.phase.ToUpper()) &mdash; $($run.date)</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
         font-size: 14px; background: #f8fafc; color: #1e293b; }

  /* Header */
  .page-header { background: #1e293b; color: #f1f5f9; padding: 16px 24px;
                 display: flex; align-items: center; gap: 16px; flex-wrap: wrap; }
  .page-header h1 { font-size: 18px; font-weight: 700; }
  .page-meta { font-size: 12px; color: #94a3b8; display: flex; gap: 12px; flex-wrap: wrap; }
  .page-meta span::before { content: '|'; margin-right: 12px; }
  .page-meta span:first-child::before { content: ''; margin: 0; }

  /* Tabs */
  .tab-bar { background: #fff; border-bottom: 2px solid #e2e8f0;
             padding: 0 24px; display: flex; gap: 4px; }
  .tab-btn { padding: 12px 20px; border: none; background: none; cursor: pointer;
             font-size: 14px; font-weight: 500; color: #64748b;
             border-bottom: 3px solid transparent; margin-bottom: -2px; transition: all 0.15s; }
  .tab-btn:hover { color: #1e293b; }
  .tab-btn.active { color: #2563eb; border-bottom-color: #2563eb; }

  /* Content area */
  .tab-panel { display: none; padding: 24px; max-width: 1000px; margin: 0 auto; }
  .tab-panel.active { display: block; }

  /* Sections */
  .section { background: #fff; border: 1px solid #e2e8f0; border-radius: 8px;
             padding: 20px; margin-bottom: 20px; }
  .section h2 { font-size: 15px; font-weight: 600; margin-bottom: 14px;
                color: #0f172a; padding-bottom: 8px; border-bottom: 1px solid #f1f5f9; }

  /* Health badge */
  .health-badge { display: inline-block; padding: 8px 16px; border-radius: 6px;
                  font-size: 16px; font-weight: 700; color: #fff; margin-bottom: 12px; }
  .health-note { padding: 12px 16px; border-radius: 6px; font-size: 13px;
                 line-height: 1.5; margin-top: 8px; }

  /* Tables */
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  thead tr { background: #f8fafc; }
  th { text-align: left; padding: 8px 12px; font-weight: 600; font-size: 12px;
       text-transform: uppercase; letter-spacing: 0.05em; color: #64748b;
       border-bottom: 2px solid #e2e8f0; }
  td { padding: 8px 12px; border-bottom: 1px solid #f1f5f9; }
  tr:last-child td { border-bottom: none; }
  tr:hover td { background: #f8fafc; }

  /* Status badges */
  .pass { color: #16a34a; font-weight: 600; }
  .warn { color: #d97706; font-weight: 600; }
  .fail { color: #dc2626; font-weight: 600; }
  .warn-badge { background: #fef9c3; color: #a16207; font-size: 11px; font-weight: 600;
                padding: 1px 6px; border-radius: 10px; vertical-align: middle; }

  /* Failed scenarios */
  .failed-scenario { background: #fef2f2; border: 1px solid #fecaca; border-radius: 6px;
                     padding: 12px 14px; margin-bottom: 10px; }
  .scenario-name { font-weight: 600; color: #991b1b; margin-bottom: 4px; }
  .scenario-path code { font-size: 12px; color: #64748b; }
  .scenario-tags { margin-top: 6px; }
  .tag { display: inline-block; background: #dbeafe; color: #1d4ed8; font-size: 11px;
         padding: 1px 7px; border-radius: 10px; margin-right: 4px; }

  /* Misc */
  .ok { color: #16a34a; }
  .action { color: #92400e; background: #fffbeb; border-left: 3px solid #d97706;
            padding: 8px 12px; border-radius: 4px; margin-top: 8px; font-size: 13px; }
  .note { font-size: 12px; color: #64748b; margin-top: 10px; line-height: 1.5; }
  ul { padding-left: 20px; }
  li { margin-bottom: 6px; line-height: 1.5; }
  code { background: #f1f5f9; padding: 1px 5px; border-radius: 4px; font-size: 12px; }
  .footer { font-size: 11px; color: #94a3b8; text-align: center; margin-top: 24px;
            padding-bottom: 24px; }
</style>
</head>
<body>

<div class="page-header">
  <h1>Quality Report</h1>
  <div class="page-meta">
    <span>$($run.phase.ToUpper())</span>
    <span>$($run.date)</span>
    <span>$($run.environment)</span>
    <span>Run #$($run.runId)</span>
  </div>
</div>

<div class="tab-bar">
  <button class="tab-btn active" id="btn-executive" onclick="showTab('executive')">Executive Summary</button>
  <button class="tab-btn" id="btn-it" onclick="showTab('it')">IT Technical Report</button>
</div>

<div id="executive" class="tab-panel active">
$execTab
</div>

<div id="it" class="tab-panel">
$itTab
</div>

<script>
function showTab(id) {
  document.querySelectorAll('.tab-panel').forEach(function(p){ p.classList.remove('active'); });
  document.querySelectorAll('.tab-btn').forEach(function(b){ b.classList.remove('active'); });
  document.getElementById(id).classList.add('active');
  document.getElementById('btn-' + id).classList.add('active');
}
</script>
</body>
</html>
"@

$html | Out-File "$ReportsDir/quality-report.html" -Encoding utf8

# ---------------------------------------------------------------------------
# Write short plain-text summary for GitHub Actions Step Summary
# ---------------------------------------------------------------------------
$leakageNote = if ($leakageCount -gt 0) { "Leakage: $leakageCount event(s)" } else { "Leakage: none" }
@"
## Quality Report - $($run.phase.ToUpper()) | $($run.date)

| | |
|---|---|
| **Health** | $healthLabel |
| **Pass Rate** | $($run.passRate)% ($($run.passed) passed, $($run.failed) failed of $($run.totalExecuted)) |
| **Coverage** | $coveragePct% of $($run.totalDefined) defined scenarios |
| **$leakageNote** | $(if($leakageCount -gt 0){"$($leakageEvents | ForEach-Object { $_.module }) (sanity -> regression)"}else{""}) |
| **Deploy to Staging** | $(if([double]$run.passRate -ge $AmberThreshold){"PASS"}else{"HOLD"}) (>= $AmberThreshold%) |
| **Deploy to Production** | $(if([double]$run.passRate -ge $GreenThreshold){"PASS"}else{"HOLD"}) (>= $GreenThreshold%) |

Full interactive report: download the **quality-metrics-$($run.runId)** artifact and open **quality-report.html**.
"@ | Out-File "$ReportsDir/quality-summary.txt" -Encoding utf8

Write-Host "Combined report written to $ReportsDir/quality-report.html"
Write-Host "Step summary written to $ReportsDir/quality-summary.txt"
