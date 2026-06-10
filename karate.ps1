<#
.SYNOPSIS
    Karate Test Runner — cross-platform wrapper for karate standalone JAR.
    Works on Windows (local) and GitHub Actions (ubuntu/windows runners).

.DESCRIPTION
    Wraps: java [jvm-flags] -jar karate-2.0.10.jar [karate-flags] [path]

# =============================================================================
# QUICK REFERENCE — ALL COMMANDS & ALIASES
# =============================================================================
#
#  COMMAND       ALIAS   DESCRIPTION
#  -----------   -----   -------------------------------------------------------
#  run           r       Run a specific feature file
#  all           a       Run all feature files under src/test/java/examples/
#  tags          t       Run tests filtered by tag(s) — supports AND / OR / NOT
#  parallel      p       Run tests in parallel (defaults to 4 threads)
#  name          n       Run a single scenario by exact name match  → -n flag
#  line          l       Run a single scenario by line number       → file:line
#  help          h       Show usage information
#
# -----------------------------------------------------------------------------
#  GLOBAL FLAGS  (combine with any command)
# -----------------------------------------------------------------------------
#  -KarateEnv <value>   Set karate.env      → -Dkarate.env=<value>
#  -Threads   <N>       Parallel threads    → -T <N>   (alias: -T)
#  -Output    <dir>     Report output dir   → --output <dir>
#  -Tags2     <@tag>    Second tag (AND)    → --tags <tag1> --tags <tag2>
#
# -----------------------------------------------------------------------------
#  EXAMPLES
# -----------------------------------------------------------------------------
#  .\karate.ps1 run   users/GetCall.feature
#  .\karate.ps1 run   posts/PostCall.feature  -KarateEnv staging
#  .\karate.ps1 all
#  .\karate.ps1 all   -Threads 4  -Output reports/full-run
#  .\karate.ps1 tags  "@SanityTest"                              # ALWAYS quote tags — @ is PS splat
#  .\karate.ps1 tags  "@SanityTest"  users                       # scoped to folder
#  .\karate.ps1 tags  "@SmokeTest,@SanityTest"                   # OR  logic (comma)
#  .\karate.ps1 tags  "@SmokeTest"  -Tags2 "@SanityTest"         # AND logic (multi-flag)
#  .\karate.ps1 tags  "~@RegressionTest"                         # NOT logic (tilde)
#  .\karate.ps1 parallel  users  -Threads 4
#  .\karate.ps1 parallel  posts  -Threads 2  -KarateEnv staging
#  .\karate.ps1 name  "Get user by id"  users/GetCall.feature
#  .\karate.ps1 line  users/GetCall.feature:7
#  .\karate.ps1 help
#
# -----------------------------------------------------------------------------
#  UNDERLYING KARATE CLI FLAGS (all covered by this script)
# -----------------------------------------------------------------------------
#  --tags  / -t    Filter by tag             .\karate.ps1 tags @smoke
#  --path  / -P    Feature file paths        .\karate.ps1 run  path/to/file.feature
#  --threads / -T  Parallel threads          .\karate.ps1 parallel folder -Threads 4
#  --output        Report directory          .\karate.ps1 all -Output reports/
#  -n              Scenario name match       .\karate.ps1 name "My scenario" file.feature
#  file:linenum    Run scenario at line      .\karate.ps1 line file.feature:10
#  -Dkarate.env    Set environment           .\karate.ps1 all -KarateEnv prod
#
#  TAG LOGIC CHEAT-SHEET:
#    OR  →  comma-separated in one --tags value:  "@smoke,@sanity"
#    AND →  multiple --tags flags:                -Tags2 @api
#    NOT →  tilde prefix:                         ~@slow
# =============================================================================
#>

param(
    [Parameter(Position=0)]
    [string]$Command = "help",

    [Parameter(Position=1)]
    [string]$Arg1 = "",

    [Parameter(Position=2)]
    [string]$Arg2 = "",

    # Set karate.env (e.g. dev, staging, prod)  → -Dkarate.env=<value>
    [string]$KarateEnv = "",

    # Parallel thread count  → -T <N>
    [Alias("T")]
    [int]$Threads = 0,

    # Custom report output directory  → --output <dir>
    [string]$Output = "",

    # Second tag for AND logic  → adds second --tags flag
    [string]$Tags2 = ""
)

# ── Paths ─────────────────────────────────────────────────────────────────────
$JAR  = Join-Path $PSScriptRoot "karate-2.0.10.jar"
$BASE = Join-Path $PSScriptRoot "src" | Join-Path -ChildPath "test" |
        Join-Path -ChildPath "java" | Join-Path -ChildPath "examples"

# ── Load .env for local development (never present in CI) ─────────────────────
$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            [System.Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim())
        }
    }
    Write-Host "  Loaded credentials from .env" -ForegroundColor DarkGray
}

# ── Validate JAR exists ───────────────────────────────────────────────────────
if (-not (Test-Path $JAR)) {
    Write-Host "ERROR: JAR not found at $JAR" -ForegroundColor Red
    Write-Host "Place karate-2.0.10.jar in the project root." -ForegroundColor Yellow
    exit 1
}

# ── Core runner ───────────────────────────────────────────────────────────────
function Invoke-Karate {
    param(
        [string[]]$KarateFlags = @(),
        [string]  $FeaturePath = "",
        [int]     $UseThreads  = 0
    )

    $allArgs = [System.Collections.Generic.List[string]]::new()

    # JVM flags BEFORE -jar
    # CI sets KARATE_LOGBACK=logback-ci.xml; locally the JAR built-in DEBUG config is used
    if ($env:KARATE_LOGBACK) {
        $logbackConfig = Join-Path $PSScriptRoot $env:KARATE_LOGBACK
        if (Test-Path $logbackConfig) { $allArgs.Add("-Dlogback.configurationFile=$logbackConfig") }
    }
    if ($KarateEnv) { $allArgs.Add("-Dkarate.env=$KarateEnv") }

    # Use -cp instead of -jar so src/test/java is on the classpath.
    # This makes classpath:examples/... resolve correctly for karate.callSingle() in karate-config.js.
    $src = Join-Path $PSScriptRoot "src" | Join-Path -ChildPath "test" | Join-Path -ChildPath "java"
    $sep = [System.IO.Path]::PathSeparator   # ; on Windows, : on Linux/Mac
    $allArgs.Add("-cp")
    $allArgs.Add("${JAR}${sep}${src}")
    $allArgs.Add("io.karatelabs.Main")

    # Karate flags AFTER -jar
    if ($UseThreads -gt 0) {
        $allArgs.Add("-T")
        $allArgs.Add($UseThreads.ToString())
    }
    if ($Output) {
        $allArgs.Add("--output")
        $allArgs.Add($Output)
    }
    foreach ($flag in $KarateFlags) {
        if ($flag) { $allArgs.Add($flag) }
    }
    if ($FeaturePath) { $allArgs.Add($FeaturePath) }

    Write-Host ""
    Write-Host "  ► java $($allArgs -join ' ')" -ForegroundColor Cyan
    Write-Host ""

    & java @allArgs
    exit $LASTEXITCODE
}

# ── Auto-prefix @ if missing (skip if starts with ~ for NOT logic) ────────────
function Add-TagPrefix {
    param([string]$tag)
    if ($tag -and ($tag -notmatch '^[@~]')) { return "@$tag" }
    return $tag
}

# ── Usage ─────────────────────────────────────────────────────────────────────
function Show-Usage {
    Write-Host ''
    Write-Host '  ================================================================' -ForegroundColor Yellow
    Write-Host '   Karate Test Runner  --  Quick Reference' -ForegroundColor Yellow
    Write-Host '  ================================================================' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  COMMANDS' -ForegroundColor Green
    Write-Host '    run  (r)       Run a specific feature file'
    Write-Host '    all  (a)       Run all features under examples/'
    Write-Host '    tags (t)       Run features filtered by tag(s)'
    Write-Host '    parallel (p)   Run features in parallel  [default: 4 threads]'
    Write-Host '    name (n)       Run a scenario by exact name match'
    Write-Host '    line (l)       Run a scenario by line number  (file.feature:N)'
    Write-Host '    help (h)       Show this message'
    Write-Host ''
    Write-Host '  GLOBAL FLAGS' -ForegroundColor Green
    Write-Host '    -KarateEnv VALUE   Set karate.env  (dev / staging / prod)'
    Write-Host '    -Threads N         Parallel threads  (-T is an alias)'
    Write-Host '    -Output DIR        Custom report output directory'
    Write-Host '    -Tags2 TAG         Second tag for AND logic'
    Write-Host ''
    Write-Host '  EXAMPLES' -ForegroundColor Green
    Write-Host '    .\karate.ps1 run   users/GetCall.feature'
    Write-Host '    .\karate.ps1 run   posts/PostCall.feature  -KarateEnv staging'
    Write-Host '    .\karate.ps1 all'
    Write-Host '    .\karate.ps1 all   -Threads 4  -Output reports/run1'
    Write-Host '    .\karate.ps1 tags  "@SanityTest"                        # NOTE: always quote tags'
    Write-Host '    .\karate.ps1 tags  "@SanityTest"  users              # scoped to folder'
    Write-Host '    .\karate.ps1 tags  "@SmokeTest,@SanityTest"          # OR  logic'
    Write-Host '    .\karate.ps1 tags  "@SmokeTest"  -Tags2 "@SanityTest" # AND logic'
    Write-Host '    .\karate.ps1 tags  "~@RegressionTest"                # NOT logic'
    Write-Host '    .\karate.ps1 parallel  users  -Threads 4'
    Write-Host '    .\karate.ps1 name  "Get user by id"  users/GetCall.feature'
    Write-Host '    .\karate.ps1 line  users/GetCall.feature:7'
    Write-Host ''
    Write-Host '  TAG LOGIC' -ForegroundColor Green
    Write-Host '    OR  -- comma in one tag:  .\karate.ps1 tags "@smoke,@sanity"'
    Write-Host '    AND -- -Tags2 flag:       .\karate.ps1 tags @smoke -Tags2 @api'
    Write-Host '    NOT -- tilde prefix:      .\karate.ps1 tags ~@slow'
    Write-Host ''
}

# ── Command router ────────────────────────────────────────────────────────────
switch ($Command.ToLower()) {

    # ── run / r ──────────────────────────────────────────────────────────────
    { $_ -in "run","r" } {
        if (-not $Arg1) {
            Write-Host "  ERROR: Provide a feature file path." -ForegroundColor Red
            Write-Host "  Usage: .\karate.ps1 run users/GetCall.feature"
            exit 1
        }
        # "run all" / "run a" → treat as the 'all' command
        if ($Arg1 -in "all","a") {
            Write-Host "  Running all features in: $BASE" -ForegroundColor White
            Invoke-Karate -FeaturePath $BASE -UseThreads $Threads
        }
        $featurePath = Join-Path $BASE $Arg1
        Write-Host "  Running feature: $featurePath" -ForegroundColor White
        Invoke-Karate -FeaturePath $featurePath -UseThreads $Threads
    }

    # ── all / a ──────────────────────────────────────────────────────────────
    { $_ -in "all","a" } {
        Write-Host "  Running all features in: $BASE" -ForegroundColor White
        Invoke-Karate -FeaturePath $BASE -UseThreads $Threads
    }

    # ── tags / t ─────────────────────────────────────────────────────────────
    { $_ -in "tags","t" } {
        if (-not $Arg1) {
            Write-Host "  ERROR: Provide a tag.  Example: @SanityTest" -ForegroundColor Red
            Write-Host "  Usage: .\karate.ps1 tags @SanityTest"
            exit 1
        }

        $tag1   = Add-TagPrefix $Arg1
        $scope  = if ($Arg2) { Join-Path $BASE $Arg2 } else { $BASE }
        $flags  = [System.Collections.Generic.List[string]]@("--tags", $tag1)

        if ($Tags2) {
            $tag2 = Add-TagPrefix $Tags2
            $flags.Add("--tags")
            $flags.Add($tag2)
        }

        Write-Host "  Running tag(s): $tag1$(if ($Tags2) { " AND $(Add-TagPrefix $Tags2)" })" -ForegroundColor White
        Write-Host "  Scope: $scope" -ForegroundColor White
        Invoke-Karate -KarateFlags $flags.ToArray() -FeaturePath $scope -UseThreads $Threads
    }

    # ── parallel / p ─────────────────────────────────────────────────────────
    { $_ -in "parallel","p" } {
        $effectiveThreads = if ($Threads -gt 0) { $Threads } else { 4 }
        # No folder given → run all features under examples/
        $featurePath = if ($Arg1) { Join-Path $BASE $Arg1 } else { $BASE }
        Write-Host "  Running in parallel ($effectiveThreads threads): $featurePath" -ForegroundColor White
        Invoke-Karate -FeaturePath $featurePath -UseThreads $effectiveThreads
    }

    # ── name / n ─────────────────────────────────────────────────────────────
    { $_ -in "name","n" } {
        if (-not $Arg1 -or -not $Arg2) {
            Write-Host "  ERROR: Provide scenario name AND feature file." -ForegroundColor Red
            Write-Host "  Usage: .\karate.ps1 name 'Get user by id' users/GetCall.feature"
            exit 1
        }
        $featurePath = Join-Path $BASE $Arg2
        Write-Host "  Running scenario: '$Arg1'" -ForegroundColor White
        Invoke-Karate -KarateFlags @("-n", $Arg1) -FeaturePath $featurePath -UseThreads $Threads
    }

    # ── line / l ─────────────────────────────────────────────────────────────
    { $_ -in "line","l" } {
        if (-not $Arg1) {
            Write-Host "  ERROR: Provide feature file with line number." -ForegroundColor Red
            Write-Host "  Usage: .\karate.ps1 line users/GetCall.feature:7"
            exit 1
        }
        # Split on last colon — separates file path from line number
        $lastColon = $Arg1.LastIndexOf(":")
        if ($lastColon -gt 0 -and $Arg1.Substring($lastColon + 1) -match '^\d+$') {
            $filePart  = $Arg1.Substring(0, $lastColon)
            $linePart  = $Arg1.Substring($lastColon + 1)
            $fullFile  = Join-Path $BASE $filePart
            $target    = "${fullFile}:${linePart}"
        } else {
            $target = Join-Path $BASE $Arg1
        }
        Write-Host "  Running scenario at: $target" -ForegroundColor White
        Invoke-Karate -FeaturePath $target -UseThreads $Threads
    }

    # ── help / h ─────────────────────────────────────────────────────────────
    { $_ -in "help","h","--help","-h","" } {
        Show-Usage
    }

    # ── unknown command ───────────────────────────────────────────────────────
    default {
        Write-Host "  ERROR: Unknown command '$Command'" -ForegroundColor Red
        Show-Usage
        exit 1
    }
}
