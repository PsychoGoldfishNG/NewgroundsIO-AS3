# NewgroundsIO-AS3 Test Suite - command-line build
#
# OPTIONAL. The primary way to run these tests is to open NgioUnitTest.fla in
# Flash Professional and press Ctrl+Enter - see README.md. This script exists
# so the suite can also be compiled without the IDE, which is handy as a
# syntax/type check and for anyone without Flash installed.
#
# It compiles TestRunnerStandalone.as, which builds the same on-screen controls
# the .fla provides and hands them to the same initiator.NgioUnitTest.

param(
    # Where Apache Flex (or an AIR SDK with mxmlc) lives
    [string]$FlexSdk = "C:\flex-sdk",

    # Player version to target. The .fla publishes to Flash Player 10, so 10.2
    # is the closest match; playerglobal.swc for it ships with Flash CS5/CS5.5.
    [string]$TargetPlayer = "10.2",

    # Skip the player-version matching and use whatever the SDK ships with
    [switch]$UseSdkPlayerGlobal
)

# Deliberately NOT "Stop". mxmlc writes its warnings to stderr, and Windows
# PowerShell wraps native-command stderr in ErrorRecords - under "Stop" that
# turns an ordinary compiler warning into a fatal script error. Success is
# judged by $LASTEXITCODE instead, which is what mxmlc actually reports with.
$ErrorActionPreference = "Continue"

$mxmlc = Join-Path $FlexSdk "bin\mxmlc.bat"
$testDir = $PSScriptRoot
$projectRoot = Split-Path $testDir -Parent
$buildDir = Join-Path $projectRoot "build"
$outputSwf = Join-Path $testDir "NgioUnitTest-standalone.swf"
$entryPoint = Join-Path $testDir "TestRunnerStandalone.as"

Write-Host "Building NewgroundsIO-AS3 test suite..." -ForegroundColor Cyan

if (-not (Test-Path $mxmlc)) {
    Write-Host "ERROR: mxmlc not found at $mxmlc" -ForegroundColor Red
    Write-Host "Install the Apache Flex SDK, or pass -FlexSdk <path>." -ForegroundColor Red
    exit 1
}

$env:FLEX_HOME = $FlexSdk
$playerGlobalHome = Join-Path $FlexSdk "frameworks\libs\player"

# The Flex SDK usually ships only a recent playerglobal.swc. Flash CS5/CS5.5
# include the older ones, so borrow from there when we can - it keeps this
# build honest about what the .fla actually targets. Without it, the SWF is
# built against a newer player than the IDE will ever produce.
if (-not $UseSdkPlayerGlobal) {
    $flashConfigRoots = @(
        "C:\Program Files (x86)\Adobe\Adobe Flash CS5.5\Common\Configuration\ActionScript 3.0",
        "C:\Program Files (x86)\Adobe\Adobe Flash CS5\Common\Configuration\ActionScript 3.0",
        "C:\Program Files\Adobe\Adobe Flash CS5.5\Common\Configuration\ActionScript 3.0",
        "C:\Program Files\Adobe\Adobe Flash CS5\Common\Configuration\ActionScript 3.0"
    )

    $sourceSwc = $null
    foreach ($root in $flashConfigRoots) {
        $candidate = Join-Path $root "FP10.2\playerglobal.swc"
        if (Test-Path $candidate) { $sourceSwc = $candidate; break }
    }

    if ($sourceSwc) {
        $staged = Join-Path $env:TEMP "ngio-playerglobal"
        $stagedVersionDir = Join-Path $staged $TargetPlayer
        if (-not (Test-Path $stagedVersionDir)) {
            New-Item -ItemType Directory -Force -Path $stagedVersionDir | Out-Null
        }
        Copy-Item $sourceSwc (Join-Path $stagedVersionDir "playerglobal.swc") -Force
        $playerGlobalHome = $staged
        Write-Host "Using playerglobal from Flash CS5.x (FP$TargetPlayer)" -ForegroundColor DarkGray
    } else {
        Write-Host "Flash CS5.x playerglobal not found; falling back to the SDK's." -ForegroundColor Yellow
        $TargetPlayer = $null
    }
}

$env:PLAYERGLOBAL_HOME = $playerGlobalHome

Write-Host "Flex SDK:  $FlexSdk"
Write-Host "Library:   $buildDir"
Write-Host "Tests:     $testDir"
Write-Host "Output:    $outputSwf"
Write-Host ""

$mxmlcArgs = @(
    "-output", $outputSwf,
    "-source-path+=$buildDir",
    "-source-path+=$testDir",
    "-default-size", "900", "700",
    "-default-background-color", "0xF5F5F5",
    "-default-frame-rate", "30",
    "-strict=true"
)

if ($TargetPlayer) {
    $mxmlcArgs += @("-target-player", $TargetPlayer)
}

$mxmlcArgs += $entryPoint

& $mxmlc $mxmlcArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Compilation FAILED (exit $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Built $outputSwf" -ForegroundColor Green
Write-Host ""
Write-Host "Run it in a Flash Player projector. Test output goes to trace(), so" -ForegroundColor Cyan
Write-Host "use the DEBUG player and enable flashlog.txt via mm.cfg to read it:" -ForegroundColor Cyan
Write-Host "  %HOMEDRIVE%%HOMEPATH%\mm.cfg  ->  TraceOutputFileEnable=1" -ForegroundColor DarkGray
Write-Host "  log at %APPDATA%\Macromedia\Flash Player\Logs\flashlog.txt" -ForegroundColor DarkGray
Write-Host ""
Write-Host "The .fla route is easier to read - see README.md." -ForegroundColor Cyan
