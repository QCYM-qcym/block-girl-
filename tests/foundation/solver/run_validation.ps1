param(
    [string]$Godot = 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [string]$EvidenceName = ('accept_3a_' + (Get-Date -Format 'yyyyMMdd_HHmmss')),
    [switch]$SelfTestFailure
)
$ErrorActionPreference = 'Stop'
if ($EvidenceName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Use a simple evidence folder name.' }
$solverProject = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$solverEvidence = Join-Path $solverProject ".godot/foundation-3a/$EvidenceName"
if (Test-Path -LiteralPath $solverEvidence) { throw 'Preserving evidence: choose a fresh name.' }
New-Item -ItemType Directory -Path $solverEvidence | Out-Null
$dependencies = @()
foreach ($dir in @('foundation', 'tests/foundation/solver', 'tests/foundation/level')) {
    Get-ChildItem -LiteralPath (Join-Path $solverProject $dir) -Recurse -File |
        Where-Object Extension -In @('.gd', '.ps1') | Sort-Object FullName | ForEach-Object {
            $dependencies += [pscustomobject]@{path=$_.FullName.Substring($solverProject.Length+1);sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
        }
}
$stages = @(
    @{name='action_generator';marker='ACTION_GENERATOR_PASS'},
    @{name='state_explorer';marker='STATE_EXPLORER_PASS'},
    @{name='solution_trace';marker='SOLUTION_TRACE_PASS'}
)
$results = @()
$totalChecks = 0
$execution = [ordered]@{head=(& git -C $solverProject rev-parse HEAD);branch=(& git -C $solverProject branch --show-current);godot=$Godot;dependencies=$dependencies;self_test_failure=[bool]$SelfTestFailure;stages=@();passed=$false;checks=0}
foreach ($stage in $stages) {
    $stdout = Join-Path $solverEvidence ($stage.name + '.stdout.log')
    $stderr = Join-Path $solverEvidence ($stage.name + '.stderr.log')
    $arguments = @('--headless','--path',('"'+$solverProject+'"'),'--script',('res://tests/foundation/solver/test_'+$stage.name+'.gd'),'--',('--evidence-dir="'+$solverEvidence+'"'))
    if ($SelfTestFailure -and $stage.name -eq 'action_generator') { $arguments += '--intentional-failure' }
    $process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $timedOut = -not $process.WaitForExit(60000)
    if ($timedOut) { $process.Kill(); $process.WaitForExit() }
    $process.WaitForExit()
    $outText = Get-Content -LiteralPath $stdout -Raw
    $errText = Get-Content -LiteralPath $stderr -Raw
    $match = [regex]::Match($outText, ('(?m)^' + $stage.marker + ' checks=([1-9][0-9]*)\r?$'))
    $checks = if ($match.Success) { [int]$match.Groups[1].Value } else { 0 }
    $passed = -not $timedOut -and $process.ExitCode -eq 0 -and $checks -gt 0 -and [string]::IsNullOrWhiteSpace($errText) -and ($outText+$errText) -notmatch 'SCRIPT ERROR:|ERROR:|FAIL:'
    $results += [pscustomobject]@{stage=$stage.name;passed=$passed;checks=$checks;exit_code=$process.ExitCode;timed_out=$timedOut;arguments=$arguments;stdout=$stdout;stderr=$stderr}
    $totalChecks += $checks
    $execution.stages = $results
    $execution.checks = $totalChecks
    $execution | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $solverEvidence 'execution.json') -Encoding utf8
    Write-Output $outText
    if (-not $passed) { throw "Solver stage failed: $($stage.name). Evidence: $solverEvidence. $errText" }
}
if (-not (Test-Path -LiteralPath (Join-Path $solverEvidence 'real-fixtures.json'))) { throw 'Missing real dependency fixture reports.' }
$fixtures = Get-Content -LiteralPath (Join-Path $solverEvidence 'real-fixtures.json') -Raw | ConvertFrom-Json
if ($fixtures.Count -lt 6 -or ($fixtures | Where-Object { $_.validation.status -ne 0 }).Count -gt 0) { throw 'Missing real Validator evidence.' }
$execution.passed = $true
$execution | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $solverEvidence 'execution.json') -Encoding utf8
Write-Output "FOUNDATION_STATE_EXPLORER_BFS_PASS checks=$totalChecks evidence=$solverEvidence"
