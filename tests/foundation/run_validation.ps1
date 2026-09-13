param(
    [string]$Godot = 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [string]$EvidenceName = ('run_' + (Get-Date -Format 'yyyyMMdd_HHmmss')),
    [ValidateSet('orientation','contracts','state_key','spatial','celestial','integration')]
    [string[]]$Stages = @('orientation','contracts','state_key','spatial','celestial','integration')
)
$ErrorActionPreference = 'Stop'
if ($EvidenceName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Use a simple evidence folder name.' }
$foundationProject = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$foundationEvidence = Join-Path $foundationProject ".godot/foundation-1-validation/$EvidenceName"
if (Test-Path -LiteralPath $foundationEvidence) { throw 'Preserving evidence: choose a new EvidenceName.' }
New-Item -ItemType Directory -Path $foundationEvidence -Force | Out-Null
$foundationScripts = @{
    orientation = 'orientation/test_orientation.gd'
    contracts = 'contracts/test_contracts.gd'
    state_key = 'contracts/test_state_key.gd'
    spatial = 'spatial/test_spatial.gd'
    celestial = 'celestial/test_celestial.gd'
    integration = 'integration/test_foundation_integration.gd'
}
$foundationResults = @()
foreach ($stage in $Stages) {
    $stageOut = Join-Path $foundationEvidence "$stage.stdout.log"
    $stageErr = Join-Path $foundationEvidence "$stage.stderr.log"
    $stageArgs = @('--headless','--path',('"' + $foundationProject + '"'),
        '--script',('res://tests/foundation/' + $foundationScripts[$stage]))
    $stageProcess = Start-Process -FilePath $Godot -ArgumentList $stageArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $stageOut -RedirectStandardError $stageErr
    if (-not $stageProcess.WaitForExit(60000)) {
        $stageProcess.Kill(); $stageProcess.WaitForExit()
        throw "$stage timed out; see $foundationEvidence"
    }
    $stageProcess.WaitForExit()
    $stageText = Get-Content -LiteralPath $stageOut -Raw
    $stageErrors = Get-Content -LiteralPath $stageErr -Raw
    $foundationResults += [pscustomobject]@{stage=$stage; exit_code=$stageProcess.ExitCode; stdout=$stageOut; stderr=$stageErr}
    $foundationResults | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $foundationEvidence 'results.json') -Encoding utf8
    Write-Output $stageText
    if ($stageProcess.ExitCode -ne 0 -or ($stageText + $stageErrors) -match 'SCRIPT ERROR:|ERROR:|FAIL:') {
        throw "$stage failed: $stageErrors"
    }
}
Write-Output "FOUNDATION VALIDATION PASS: $foundationEvidence"
