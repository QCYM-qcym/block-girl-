param(
    [string]$Godot = 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [string]$EvidenceName = ('runtime_' + (Get-Date -Format 'yyyyMMdd_HHmmss')),
    [switch]$IncludeRegressions
)
$ErrorActionPreference = 'Stop'
if ($EvidenceName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Use a simple evidence folder name.' }
$runtimeProject = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$runtimeEvidence = Join-Path $runtimeProject ".godot/foundation-2d-evidence/$EvidenceName"
if (Test-Path -LiteralPath $runtimeEvidence) { throw 'Preserving evidence: choose a new EvidenceName.' }
New-Item -ItemType Directory -Path $runtimeEvidence -Force | Out-Null
$runtimeResults = @()
$runtimeStages = @('input_mapper','runtime_session','runtime_graphics')
if ($IncludeRegressions) { $runtimeStages = @('import') + $runtimeStages }
foreach ($stage in $runtimeStages) {
    $runtimeOut = Join-Path $runtimeEvidence "$stage.stdout.log"
    $runtimeErr = Join-Path $runtimeEvidence "$stage.stderr.log"
    $runtimeArgs = @('--path', ('"' + $runtimeProject + '"'))
    if ($stage -eq 'import') { $runtimeArgs += @('--headless','--editor','--import') }
    else {
        $runtimeArgs += @('--script', "res://tests/foundation/runtime/test_$stage.gd")
        if ($stage -ne 'runtime_graphics') { $runtimeArgs += '--headless' }
        else { $runtimeArgs += @('--max-fps','60','--',('--evidence-dir="' + $runtimeEvidence + '"')) }
    }
    $runtimeProcess = Start-Process -FilePath $Godot -ArgumentList $runtimeArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $runtimeOut -RedirectStandardError $runtimeErr
    $runtimeTimedOut = -not $runtimeProcess.WaitForExit(60000)
    if ($runtimeTimedOut) { $runtimeProcess.Kill(); $runtimeProcess.WaitForExit() }
    $runtimeProcess.WaitForExit()
    $runtimeText = Get-Content -LiteralPath $runtimeOut -Raw
    $runtimeErrors = Get-Content -LiteralPath $runtimeErr -Raw
    $runtimePassed = -not $runtimeTimedOut -and $runtimeProcess.ExitCode -eq 0 -and ($stage -eq 'import' -or $runtimeText -match 'FOUNDATION_[A-Z_]+_PASS') -and ($runtimeText + $runtimeErrors) -notmatch 'SCRIPT ERROR:|ERROR:|FAIL:'
    $runtimeResults += [pscustomobject]@{stage=$stage; passed=$runtimePassed; exit_code=$runtimeProcess.ExitCode; timed_out=$runtimeTimedOut; stdout=$runtimeOut; stderr=$runtimeErr}
    $runtimeResults | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runtimeEvidence 'results.json') -Encoding utf8
    Write-Output $runtimeText
    if (-not $runtimePassed) { throw "$stage failed: $runtimeErrors (see $runtimeEvidence)" }
    if ($stage -eq 'import') { Write-Output 'FOUNDATION_RUNTIME_IMPORT_PASS' }
}
$runtimeReport = Get-Content -LiteralPath (Join-Path $runtimeEvidence 'runtime_report.json') -Raw | ConvertFrom-Json
if ($runtimeReport.display -eq 'headless' -or $runtimeReport.failures.Count -ne 0) { throw 'Actual graphical validation did not pass.' }
if ($IncludeRegressions) {
    & (Join-Path $runtimeProject 'tests/foundation/run_validation.ps1') -Godot $Godot -EvidenceName ($EvidenceName + '_foundation')
    & (Join-Path $runtimeProject 'tests/gameplay/run_p01_validation.ps1') -Godot $Godot -EvidenceName ($EvidenceName + '_p01') -IncludeRegressions
}
Write-Output "FOUNDATION_RUNTIME_PROTOTYPE_PASS (explicit contract double; real Kernel/Safety integration NOT RUN): $runtimeEvidence"
