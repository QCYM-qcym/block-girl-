param(
    [string]$Godot = 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [string]$EvidenceName = ('parity_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
)
$ErrorActionPreference = 'Stop'
if ($EvidenceName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Use a simple evidence folder name.' }
if (-not (Test-Path -LiteralPath $Godot)) { throw "Godot not found: $Godot" }
$parityProject = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$parityEvidence = Join-Path $parityProject ".godot/foundation-3d/$EvidenceName"
if (Test-Path -LiteralPath $parityEvidence) { throw 'Preserving evidence: choose a fresh EvidenceName.' }
New-Item -ItemType Directory -Path $parityEvidence -Force | Out-Null
$solverCommit = 'f34dd271adabcc4b724eb55b5fff1cb35f532e59'
$solverPaths = @(& git -C $parityProject ls-tree -r --name-only $solverCommit -- foundation/solver)
if ($LASTEXITCODE -ne 0 -or $solverPaths.Count -ne 14) { throw 'Pinned formal 3A commit is unavailable.' }
foreach ($solverPath in $solverPaths) {
    $expectedBlob = & git -C $parityProject rev-parse ($solverCommit + ':' + $solverPath)
    $actualBlob = & git -C $parityProject hash-object --path=$solverPath (Join-Path $parityProject $solverPath)
    if ($LASTEXITCODE -ne 0 -or $actualBlob -ne $expectedBlob) { throw "Formal 3A dependency differs from pinned commit: $solverPath" }
}
$parityDependencies = @()
foreach ($parityDirectory in @('foundation','tests/foundation/parity','prototype/foundation/runtime','tools/foundation/level')) {
    Get-ChildItem -LiteralPath (Join-Path $parityProject $parityDirectory) -Recurse -File |
        Where-Object Extension -In @('.gd','.tscn','.ps1') | Sort-Object FullName | ForEach-Object {
            $parityDependencies += [pscustomobject]@{path=$_.FullName.Substring($parityProject.Length+1);sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
        }
}
$parityStages = @(
    @{name='logical';script='test_trace_replayer.gd';report='headless_report.json';headless=$true},
    @{name='graphical';script='test_parity_graphics.gd';report='graphics.json';headless=$false},
    @{name='real_trace_logical';script='test_solver_trace_integration.gd';report='real_trace_logical.json';headless=$true},
    @{name='real_trace_graphical';script='test_solver_trace_integration.gd';report='real_trace_graphical.json';headless=$false}
)
$parityRuns = @()
foreach ($parityStage in $parityStages) {
    $parityOut = Join-Path $parityEvidence ($parityStage.name + '.stdout.log')
    $parityErr = Join-Path $parityEvidence ($parityStage.name + '.stderr.log')
    $parityArguments = @('--path',('"'+$parityProject+'"'),'--script',('res://tests/foundation/parity/'+$parityStage.script),'--max-fps','60')
    if ($parityStage.headless) { $parityArguments += '--headless' }
    $parityArguments += @('--',('--evidence-dir="'+$parityEvidence+'"'))
    $parityProcess = $null
    try {
        $parityProcess = Start-Process -FilePath $Godot -ArgumentList $parityArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $parityOut -RedirectStandardError $parityErr
        $parityTimedOut = -not $parityProcess.WaitForExit(60000)
        if ($parityTimedOut) { $parityProcess.Kill(); $parityProcess.WaitForExit() }
        $parityProcess.WaitForExit()
        $parityText = Get-Content -LiteralPath $parityOut -Raw
        $parityErrors = Get-Content -LiteralPath $parityErr -Raw
        $parityPassed = -not $parityTimedOut -and $parityProcess.ExitCode -eq 0 -and $parityText -match 'FOUNDATION_PARITY_[A-Z_]+_PASS checks=[1-9][0-9]*' -and [string]::IsNullOrWhiteSpace($parityErrors) -and ($parityText+$parityErrors) -notmatch 'SCRIPT ERROR:|ERROR:|FAIL:'
        $parityRuns += [pscustomobject]@{stage=$parityStage.name;passed=$parityPassed;exit_code=$parityProcess.ExitCode;timed_out=$parityTimedOut;stdout=$parityOut;stderr=$parityErr}
        [pscustomobject]@{head=(& git -C $parityProject rev-parse HEAD);runs=$parityRuns;dependencies=$parityDependencies;solver_commit=$solverCommit;solver_blobs_verified=$true;dependency_pending=$null} |
            ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $parityEvidence 'execution.json') -Encoding utf8
        Write-Output $parityText
        if (-not $parityPassed) { throw "$($parityStage.name) failed: $parityErrors (evidence $parityEvidence)" }
        $parityReport = Get-Content -LiteralPath (Join-Path $parityEvidence $parityStage.report) -Raw | ConvertFrom-Json
        if ($parityReport.checks -le 0 -or $parityReport.failures.Count -ne 0) { throw 'Invalid check report.' }
        if (-not $parityStage.headless -and ([string]::IsNullOrWhiteSpace($parityReport.display) -or $parityReport.display -eq 'headless')) { throw 'Graphical stage must use a real display.' }
    } finally {
        if ($null -ne $parityProcess -and -not $parityProcess.HasExited) { $parityProcess.Kill(); $parityProcess.WaitForExit() }
    }
}
Write-Output "FOUNDATION_PARITY_SUITES_PASS evidence=$parityEvidence"
Write-Output "REAL_3A_SOLUTION_TRACE_CONSUMED commit=$solverCommit"
Write-Output 'Overall FOUNDATION_RUNTIME_PARITY_PASS additionally requires the unchanged FOUNDATION-2 graphical and Runtime regressions.'
