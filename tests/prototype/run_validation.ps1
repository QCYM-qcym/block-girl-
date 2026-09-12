param(
    [string]$Godot = 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [string]$EvidenceName = ('run_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
)
$ErrorActionPreference = 'Stop'
if ($EvidenceName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'EvidenceName must be a simple folder name.' }
if (-not (Test-Path -LiteralPath $Godot)) { throw "Godot not found: $Godot" }
$prototypeProject = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$prototypeEvidence = Join-Path $PSScriptRoot "evidence/$EvidenceName"
if (Test-Path -LiteralPath $prototypeEvidence) { throw "Use a new evidence name; preserving existing run: $prototypeEvidence" }
New-Item -ItemType Directory -Path $prototypeEvidence | Out-Null
foreach ($stage in @('import','state','input','runtime')) {
    $prototypeArgs = @('--path', ('"' + $prototypeProject + '"'))
    if ($stage -eq 'import') { $prototypeArgs += @('--headless','--editor','--import') }
    elseif ($stage -in @('state','input')) { $prototypeArgs += @('--headless','--script',"res://tests/prototype/test_$stage.gd") }
    else { $prototypeArgs += @('--max-fps','60','--script','res://tests/prototype/test_runtime.gd','--',('--evidence-dir="' + $prototypeEvidence + '"')) }
    $prototypeWindowStyle = if ($stage -eq 'runtime') { 'Normal' } else { 'Hidden' }
    $prototypeProcess = Start-Process -FilePath $Godot -ArgumentList $prototypeArgs -WindowStyle $prototypeWindowStyle -PassThru -RedirectStandardOutput (Join-Path $prototypeEvidence "$stage.stdout.log") -RedirectStandardError (Join-Path $prototypeEvidence "$stage.stderr.log")
    if (-not $prototypeProcess.WaitForExit(180000)) {
        $prototypeProcess.Kill()
        throw "$stage timed out after 180 seconds."
    }
    $prototypeProcess.WaitForExit()
    $prototypeErrors = Get-Content -LiteralPath (Join-Path $prototypeEvidence "$stage.stderr.log") -Raw
    $prototypeOutput = Get-Content -LiteralPath (Join-Path $prototypeEvidence "$stage.stdout.log") -Raw
    Write-Output $prototypeOutput
    if ($prototypeProcess.ExitCode -ne 0 -or $prototypeErrors -match 'SCRIPT ERROR:|ERROR:|FAIL:') {
        throw "$stage failed (exit $($prototypeProcess.ExitCode)): $prototypeErrors"
    }
}
$prototypeReport = Get-Content -LiteralPath (Join-Path $prototypeEvidence 'runtime_report.json') -Raw | ConvertFrom-Json
if ($prototypeReport.failures.Count -ne 0 -or $prototypeReport.display_server -eq 'headless') { throw 'Graphical runtime validation did not pass.' }
Write-Output "PLAYABLE_PUZZLE_PROTOTYPE_01_PASS — $prototypeEvidence"
