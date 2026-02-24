# NewgroundsIO-AS3 Test Build Script
# Compiles the test runner into a standalone SWF

Write-Host "Building NewgroundsIO-AS3 Test Suite..." -ForegroundColor Cyan

$flexSdk = "C:\flex-sdk"
$mxmlc = "$flexSdk\bin\mxmlc.bat"
$projectRoot = Split-Path $PSScriptRoot -Parent
$buildDir = Join-Path $projectRoot "build"
$testDir = $PSScriptRoot
$outputSwf = Join-Path $testDir "TestRunner.swf"

# Check if Flex SDK is installed
if (-not (Test-Path $mxmlc)) {
    Write-Host "ERROR: Flex SDK not found at $flexSdk" -ForegroundColor Red
    Write-Host "Please install Apache Flex SDK first." -ForegroundColor Red
    exit 1
}

Write-Host "Flex SDK: $flexSdk" -ForegroundColor Green
Write-Host "Build Dir: $buildDir" -ForegroundColor Green
Write-Host "Test Dir: $testDir" -ForegroundColor Green

# Set up environment variables for Flex SDK
$env:FLEX_HOME = $flexSdk
$env:PLAYERGLOBAL_HOME = "$flexSdk\frameworks\libs\player"

# Build the test SWF
Write-Host "`nCompiling test runner..." -ForegroundColor Yellow

$sourcePaths = @(
    $buildDir,
    $testDir
)

$sourcePathArg = ($sourcePaths | ForEach-Object { "-source-path+=$_" }) -join " "

$compileCmd = "& `"$mxmlc`" -output `"$outputSwf`" $sourcePathArg -default-size 800 600 -default-background-color 0xF5F5F5 -default-frame-rate 30 -target-player 11.1 `"$testDir\TestRunner.as`""

Write-Host "Running: $compileCmd" -ForegroundColor Gray

try {
    Invoke-Expression $compileCmd
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nTest suite compiled successfully!" -ForegroundColor Green
        Write-Host "Output: $outputSwf" -ForegroundColor Green
        Write-Host "`nTo run tests, open $outputSwf in Flash Player" -ForegroundColor Cyan
    } else {
        Write-Host "`nCompilation failed with exit code $LASTEXITCODE" -ForegroundColor Red
        exit $LASTEXITCODE
    }
} catch {
    Write-Host "`nCompilation error: $_" -ForegroundColor Red
    exit 1
}
