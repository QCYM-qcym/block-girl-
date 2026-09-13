param(
    [string]$Godot = 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [string]$EvidenceName = ('run_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
)
$ErrorActionPreference = 'Stop'
if ($EvidenceName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Use a simple evidence folder name.' }
$integrationRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$integrationEvidence = Join-Path $integrationRoot ".godot/kernel-safety-integration/$EvidenceName"
if (Test-Path -LiteralPath $integrationEvidence) { throw 'Preserving existing evidence: choose a new name.' }
New-Item -ItemType Directory -Path $integrationEvidence -Force | Out-Null
$integrationOut = Join-Path $integrationEvidence 'integration.stdout.log'
$integrationErr = Join-Path $integrationEvidence 'integration.stderr.log'
$integrationDependencies = @(Get-ChildItem -LiteralPath (Join-Path $integrationRoot 'foundation') -Recurse -Filter '*.gd' | Sort-Object FullName | ForEach-Object {
    [pscustomobject]@{path=[IO.Path]::GetRelativePath($integrationRoot,$_.FullName);sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
})
$integrationArgs = @('--headless','--path',('"' + $integrationRoot + '"'),'--script','res://tests/foundation/kernel_safety/test_kernel_safety.gd')
$integrationProcess = Start-Process -FilePath $Godot -ArgumentList $integrationArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $integrationOut -RedirectStandardError $integrationErr
$integrationTimedOut = -not $integrationProcess.WaitForExit(60000)
if ($integrationTimedOut) { $integrationProcess.Kill() }
$integrationProcess.WaitForExit()
$integrationText = [string](Get-Content -LiteralPath $integrationOut -Raw)
$integrationErrors = [string](Get-Content -LiteralPath $integrationErr -Raw)
$integrationCount = 0
if ($integrationText -match 'KERNEL_SAFETY_INTEGRATION checks=(\d+) failures=\[\]') { $integrationCount = [int]$Matches[1] }
$integrationPass = -not $integrationTimedOut -and $integrationProcess.ExitCode -eq 0 -and $integrationCount -gt 0 -and $integrationText -match 'KERNEL_SAFETY_REAL_SUITE_PASS' -and [string]::IsNullOrWhiteSpace($integrationErrors) -and ($integrationText + $integrationErrors) -notmatch 'SCRIPT ERROR:|ERROR:|FAIL:'
[pscustomobject]@{head=(& git -C $integrationRoot rev-parse HEAD).Trim();mode='REAL_SAFETY';checks=$integrationCount;exit_code=$integrationProcess.ExitCode;timed_out=$integrationTimedOut;passed=$integrationPass;dependencies=$integrationDependencies;stdout=$integrationOut;stderr=$integrationErr} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $integrationEvidence 'results.json') -Encoding utf8
Write-Output $integrationText
if (-not $integrationPass) { throw "Kernel Safety verification failed: $integrationErrors; see $integrationEvidence" }
Write-Output "KERNEL_SAFETY_VERIFICATION_PASS checks=$integrationCount; evidence=$integrationEvidence"
