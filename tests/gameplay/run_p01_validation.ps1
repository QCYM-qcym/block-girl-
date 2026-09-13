param(
    [string]$Godot = 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [string]$EvidenceName = ('p01_' + (Get-Date -Format 'yyyyMMdd_HHmmss')),
    [switch]$IncludeRegressions
)
$ErrorActionPreference = 'Stop'
if ($EvidenceName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Use a simple evidence folder name.' }
$p01Project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$p01Evidence = Join-Path $PSScriptRoot "evidence/$EvidenceName"
if (Test-Path -LiteralPath $p01Evidence) { throw 'Preserving prior evidence: choose a new EvidenceName.' }
New-Item -ItemType Directory -Path $p01Evidence | Out-Null
foreach ($stage in @('state','runtime')) {
    $p01Args = @('--path', ('"' + $p01Project + '"'), '--script', "res://tests/gameplay/test_p01_$stage.gd")
    if ($stage -eq 'state') { $p01Args += '--headless' }
    else { $p01Args += @('--max-fps','60','--', ('--evidence-dir="' + $p01Evidence + '"')) }
    $p01Out = Join-Path $p01Evidence "$stage.stdout.log"
    $p01Err = Join-Path $p01Evidence "$stage.stderr.log"
    $p01Process = Start-Process -FilePath $Godot -ArgumentList $p01Args -WindowStyle Hidden -PassThru -RedirectStandardOutput $p01Out -RedirectStandardError $p01Err
    if (-not $p01Process.WaitForExit(120000)) { $p01Process.Kill(); $p01Process.WaitForExit(); throw "$stage timed out" }
    $p01Process.WaitForExit()
    Get-Content -LiteralPath $p01Out
    $p01Errors = Get-Content -LiteralPath $p01Err -Raw
    if ($p01Process.ExitCode -ne 0 -or $p01Errors -match 'ERROR:|FAIL:') { throw "$stage failed: $p01Errors" }
}
$p01Report = Get-Content -LiteralPath (Join-Path $p01Evidence 'runtime_report.json') -Raw | ConvertFrom-Json
if ($p01Report.display -eq 'headless' -or $p01Report.failures.Count -ne 0) { throw 'Graphical P01 runtime did not pass.' }
if ($IncludeRegressions) {
    & (Join-Path $PSScriptRoot 'run_validation.ps1') -Godot $Godot -EvidenceName ($EvidenceName + '_regression') -IncludeRegressions
}
Write-Output "P01 AUTOMATED VALIDATION PASS: $p01Evidence"
