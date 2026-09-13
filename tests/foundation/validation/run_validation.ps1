param(
    [string]$Godot = 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [string]$EvidenceName = ('run_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
)
$ErrorActionPreference = 'Stop'
if ($EvidenceName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Use a simple evidence folder name.' }
$validatorProject = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$validatorEvidence = Join-Path $validatorProject ".godot/foundation-2b-validation/$EvidenceName"
if (Test-Path -LiteralPath $validatorEvidence) { throw 'Preserving evidence: choose a new EvidenceName.' }
New-Item -ItemType Directory -Path $validatorEvidence -Force | Out-Null
$validatorHead = (& git -C $validatorProject rev-parse HEAD).Trim()
$validatorDependencies = @()
foreach ($owner in @('contracts','orientation','spatial','celestial','validation')) {
    foreach ($script in Get-ChildItem -LiteralPath (Join-Path $validatorProject "foundation/$owner") -Filter '*.gd' | Sort-Object Name) {
        $validatorDependencies += [pscustomobject]@{path="foundation/$owner/$($script.Name)"; sha256=(Get-FileHash -LiteralPath $script.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
    }
}
$validatorResults = @()
$validatorFailures = @()
foreach ($stage in @('safety_queries','static_validator')) {
    $validatorOut = Join-Path $validatorEvidence "$stage.stdout.log"
    $validatorErr = Join-Path $validatorEvidence "$stage.stderr.log"
    $validatorArguments = @('--headless','--path',('"' + $validatorProject + '"'),'--script',"res://tests/foundation/validation/test_$stage.gd")
    $validatorProcess = Start-Process -FilePath $Godot -ArgumentList $validatorArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $validatorOut -RedirectStandardError $validatorErr
    $validatorTimedOut = -not $validatorProcess.WaitForExit(60000)
    if ($validatorTimedOut) { $validatorProcess.Kill() }
    $validatorProcess.WaitForExit()
    $validatorText = [string](Get-Content -LiteralPath $validatorOut -Raw)
    $validatorErrors = [string](Get-Content -LiteralPath $validatorErr -Raw)
    $validatorCount = $null
    $validatorPattern = if ($stage -eq 'safety_queries') { 'SAFETY CHECKS: (\d+); FAILURES: 0' } else { 'STATIC_VALIDATOR checks=(\d+) failures=\[\]' }
    if ($validatorText -match $validatorPattern) { $validatorCount = [int]$Matches[1] }
    if ($validatorTimedOut -or $validatorProcess.ExitCode -ne 0 -or $null -eq $validatorCount -or -not [string]::IsNullOrWhiteSpace($validatorErrors) -or ($validatorText + $validatorErrors) -match 'SCRIPT ERROR:|ERROR:|FAIL:') {
        $validatorFailures += $stage
    }
    $validatorResults += [pscustomobject]@{stage=$stage; checks=$validatorCount; exit_code=$validatorProcess.ExitCode; timed_out=$validatorTimedOut; stdout=$validatorOut; stderr=$validatorErr}
    Write-Output $validatorText
}
$validatorReport = [pscustomobject]@{head=$validatorHead; dependencies=$validatorDependencies; stages=$validatorResults; checks=($validatorResults | Measure-Object -Property checks -Sum).Sum; failures=@($validatorFailures)}
$validatorReport | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $validatorEvidence 'results.json') -Encoding utf8
if ($validatorFailures.Count -gt 0) { throw "Static Validator verification failed: $($validatorFailures -join ', '); see $validatorEvidence" }
Write-Output "FOUNDATION_STATIC_VALIDATOR_PASS checks=$($validatorReport.checks); failures=[]; evidence=$validatorEvidence"
