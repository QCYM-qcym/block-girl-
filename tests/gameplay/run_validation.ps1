param(
    [string]$Godot = 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [string]$EvidenceName = ('run_' + (Get-Date -Format 'yyyyMMdd_HHmmss')),
    [switch]$IncludeRegressions
)
$ErrorActionPreference = 'Stop'
if ($EvidenceName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Use a simple evidence folder name.' }
if (-not (Test-Path -LiteralPath $Godot)) { throw "Godot not found: $Godot" }
$perspectiveProject = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$perspectiveEvidence = Join-Path $PSScriptRoot "evidence/$EvidenceName"
if (Test-Path -LiteralPath $perspectiveEvidence) { throw 'Preserving prior evidence: choose a new EvidenceName.' }
New-Item -ItemType Directory -Path $perspectiveEvidence | Out-Null
function Invoke-ValidationStage([string]$Stage, [string[]]$ExtraArgs) {
    $stageOut = Join-Path $perspectiveEvidence "$Stage.stdout.log"
    $stageErr = Join-Path $perspectiveEvidence "$Stage.stderr.log"
    $stageArgs = @('--path', ('"' + $perspectiveProject + '"')) + $ExtraArgs
    # The legacy tileset harness unconditionally re-saves this sample with new
    # node IDs. Preserve its exact bytes without modifying the old harness.
    $samplePath = Join-Path $perspectiveProject 'tests/visual/tileset_paired_sample.tscn'
    $sampleBytes = if ($Stage -eq 'tileset') { [IO.File]::ReadAllBytes($samplePath) } else { $null }
    try {
        $stageProcess = Start-Process -FilePath $Godot -ArgumentList $stageArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $stageOut -RedirectStandardError $stageErr
        if (-not $stageProcess.WaitForExit(180000)) { $stageProcess.Kill(); $stageProcess.WaitForExit(); throw "$Stage timed out." }
        $stageProcess.WaitForExit()
    } finally {
        if ($null -ne $sampleBytes) { [IO.File]::WriteAllBytes($samplePath, [byte[]]$sampleBytes) }
    }
    $stageErrors = Get-Content -LiteralPath $stageErr -Raw
    Get-Content -LiteralPath $stageOut
    if ($stageProcess.ExitCode -ne 0 -or $stageErrors -match 'SCRIPT ERROR:|ERROR:|FAIL:') { throw "$Stage failed: $stageErrors" }
}
Invoke-ValidationStage 'import' @('--headless','--editor','--import')
Invoke-ValidationStage 'logic' @('--headless','--script','res://tests/gameplay/test_perspective_logic.gd')
Invoke-ValidationStage 'bugfix' @('--max-fps','60','--script','res://tests/gameplay/test_perspective_bugfix.gd','--',('--evidence-dir="'+(Join-Path $perspectiveEvidence 'bugfix')+'"'))
Invoke-ValidationStage 'runtime' @('--max-fps','60','--script','res://tests/gameplay/test_perspective_runtime.gd','--',('--evidence-dir="'+$perspectiveEvidence+'"'))
$runtimeReport = Get-Content -LiteralPath (Join-Path $perspectiveEvidence 'runtime_report.json') -Raw | ConvertFrom-Json
if ($runtimeReport.display -eq 'headless' -or $runtimeReport.failures.Count -ne 0) { throw 'Graphical runtime did not pass.' }
if ($IncludeRegressions) {
    foreach ($oldStage in @('state','input')) {
        Invoke-ValidationStage "puzzle01_$oldStage" @('--headless','--script',"res://tests/prototype/test_$oldStage.gd")
    }
    Invoke-ValidationStage 'puzzle01_runtime' @('--max-fps','60','--script','res://tests/prototype/test_runtime.gd','--',('--evidence-dir="'+(Join-Path $perspectiveEvidence 'puzzle01')+'"'))
    foreach ($visual in @('sprite','tileset','mechanism')) {
        Invoke-ValidationStage $visual @('--max-fps','60',"res://tests/visual/${visual}_runtime_test.tscn",'--','--auto',('--evidence-dir="'+(Join-Path $perspectiveEvidence $visual)+'"'))
    }
}
Write-Output "PERSPECTIVE AUTOMATED VALIDATION PASS: $perspectiveEvidence"
