param(
    [string]$Godot = 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [string]$EvidenceName = ('intent_' + (Get-Date -Format 'yyyyMMdd_HHmmss')),
    [string]$SolverSourceRoot = ''
)
$ErrorActionPreference = 'Stop'
if ($EvidenceName -notmatch '\A[a-zA-Z0-9_-]+\z') { throw 'Use a simple evidence folder name.' }
if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) { throw 'Godot executable missing.' }
$intentRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../../..')).Path
$intentEvidence = Join-Path $intentRoot ".godot/foundation-3c/$EvidenceName"
if (Test-Path -LiteralPath $intentEvidence) { throw 'Preserving existing evidence; choose a new EvidenceName.' }
$intentProject = Join-Path $intentEvidence 'project'
New-Item -ItemType Directory -Path $intentProject -Force | Out-Null
$manifest = [Collections.Generic.List[object]]::new()
function Copy-Source([string]$Relative) {
    $source = Join-Path $intentRoot $Relative
    $destination = Join-Path $intentProject $Relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination
    $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
    $copyHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($sourceHash -cne $copyHash) { throw "Copied source mismatch: $Relative" }
    $manifest.Add([pscustomobject]@{path=$Relative; source_sha256=$sourceHash; copy_sha256=$copyHash})
}
foreach ($relativeDirectory in @('foundation','tests/foundation/quality/intent')) {
    Get-ChildItem -LiteralPath (Join-Path $intentRoot $relativeDirectory) -Recurse -File |
        Where-Object { $_.Name -match '\.gd(?:\.uid)?$' } | Sort-Object FullName | ForEach-Object {
            Copy-Source $_.FullName.Substring($intentRoot.Length + 1)
        }
}
foreach ($fixture in @('tests/foundation/rules/kernel_fixture.gd','tests/foundation/level/baker_fixture.gd')) { Copy-Source $fixture }
Copy-Source 'tests/foundation/quality/intent/run_validation.ps1'
[IO.File]::WriteAllText((Join-Path $intentProject 'project.godot'), "config_version=5`n", [Text.UTF8Encoding]::new($false))
$solverFiles = [Collections.Generic.List[object]]::new()
if (-not [string]::IsNullOrWhiteSpace($SolverSourceRoot)) {
    $solverRoot = (Resolve-Path -LiteralPath $SolverSourceRoot).Path
    $solverDirectory = Join-Path $solverRoot 'foundation/solver'
    foreach ($module in @('solver_types','search_records','action_generator','state_graph','state_explorer','bfs_solver','solution_trace')) {
        foreach ($extension in @('.gd','.gd.uid')) {
            $source = Join-Path $solverDirectory ($module+$extension)
            if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Formal 3A dependency missing: $source" }
            $solverFiles.Add([pscustomobject]@{path=$source; sha256=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()})
        }
    }
    $mount = Join-Path $intentProject 'foundation/solver'
    if (Test-Path -LiteralPath $mount) { throw 'A local Solver dependency already exists; do not replace it.' }
    # A tests-only read-through mount; no 3A production algorithms are copied.
    New-Item -ItemType Junction -Path $mount -Target $solverDirectory | Out-Null
}
$realDependency = (Test-Path -LiteralPath (Join-Path $intentProject 'foundation/solver/bfs_solver.gd')) -and
    (Test-Path -LiteralPath (Join-Path $intentProject 'foundation/solver/solution_trace.gd')) -and
    (Test-Path -LiteralPath (Join-Path $intentProject 'foundation/solver/search_records.gd'))
[pscustomobject]@{head=(& git -C $intentRoot rev-parse HEAD); dependency=$(if ($realDependency) {'REAL_3A_SOLVER'} else {'DEPENDENCY_PENDING: REAL_3A_SOLVER'}); solver_source=$SolverSourceRoot; solver_files=@($solverFiles); files=@($manifest)} |
    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $intentEvidence 'source_manifest.json') -Encoding utf8
$stages = @(
    @('test_intent_validation.gd','INTENT_VALIDATION_PASS'),
    @('test_mechanic_classifier.gd','MECHANIC_CLASSIFIER_PASS'),
    @('test_ablation_analyzer.gd','ABLATION_ANALYZER_PROVISIONAL_PASS'),
    @('test_milestone_analyzer.gd','MILESTONE_ANALYZER_PROVISIONAL_PASS'),
    @('test_intent_integration.gd',$(if ($realDependency) {'INTENT_INTEGRATION_PASS'} else {'INTENT_INTEGRATION_PROVISIONAL_PASS'}))
)
$results = [Collections.Generic.List[object]]::new()
foreach ($stage in $stages) {
    $name = [IO.Path]::GetFileNameWithoutExtension($stage[0])
    $stdout = Join-Path $intentEvidence "$name.stdout.log"
    $stderr = Join-Path $intentEvidence "$name.stderr.log"
    $arguments = @('--headless','--path',('"'+$intentProject+'"'),'--script',('res://tests/foundation/quality/intent/'+$stage[0]),'--',('--evidence-dir="'+$intentEvidence+'"'))
    $process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $timedOut = -not $process.WaitForExit(60000)
    if ($timedOut) { $process.Kill(); $process.WaitForExit() }
    $process.WaitForExit()
    $outText = [IO.File]::ReadAllText($stdout)
    $errText = [IO.File]::ReadAllText($stderr)
    $passed = -not $timedOut -and $process.ExitCode -eq 0 -and
        $outText -match 'checks=[1-9][0-9]* failures=\[\]' -and
        $outText -match [regex]::Escape($stage[1]) -and [string]::IsNullOrWhiteSpace($errText) -and
        ($outText+$errText) -notmatch 'SCRIPT ERROR:|ERROR:|FAIL:'
    $results.Add([pscustomobject]@{stage=$name; passed=$passed; exit_code=$process.ExitCode; timed_out=$timedOut; stdout=$stdout; stderr=$stderr})
    @($results) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $intentEvidence 'results.json') -Encoding utf8
    Write-Output $outText
    if (-not $passed) { throw "Intent stage failed: $name ($intentEvidence) $errText" }
}
foreach ($dependency in $solverFiles) {
    if ((Get-FileHash -LiteralPath $dependency.path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $dependency.sha256) { throw "Formal 3A source changed during validation: $($dependency.path)" }
}
if ($realDependency) {
    Write-Output 'FOUNDATION_PUZZLE_INTENT_ABLATION_PASS'
    Write-Output 'CONTRACT_MISMATCH: NONE'
} else {
    Write-Output 'FOUNDATION_PUZZLE_INTENT_ABLATION_PROVISIONAL_PASS'
    Write-Output 'DEPENDENCY_PENDING: REAL_3A_SOLVER'
}
Write-Output "Evidence: $intentEvidence"
