param(
    [string]$Godot = 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [string]$EvidenceName = ('accept_3b_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
)
$ErrorActionPreference = 'Stop'
if ($EvidenceName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Use a simple evidence folder name.' }
$softlockProject = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../../..')).Path
$softlockEvidence = Join-Path $softlockProject ".godot/foundation-3b/$EvidenceName"
if (Test-Path -LiteralPath $softlockEvidence) { throw 'Preserving evidence: choose a fresh EvidenceName.' }
New-Item -ItemType Directory -Path $softlockEvidence -Force | Out-Null
$softlockDependencies = @()
foreach ($dir in @('foundation','tests/foundation/quality/softlock')) {
    foreach ($script in Get-ChildItem -LiteralPath (Join-Path $softlockProject $dir) -Recurse -File | Where-Object Extension -In @('.gd','.ps1') | Sort-Object FullName) {
        $softlockDependencies += [pscustomobject]@{path=$script.FullName.Substring($softlockProject.Length+1);sha256=(Get-FileHash -LiteralPath $script.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
    }
}
$softlockResults = @()
$softlockFailures = @()
$softlockPending = $false
$softlockGraphEvidence = @()
foreach ($stage in @('unit','integration')) {
    $softlockScript = if ($stage -eq 'unit') { 'test_softlock_analyzer.gd' } else { 'test_softlock_integration.gd' }
    $softlockOut = Join-Path $softlockEvidence "$stage.stdout.log"
    $softlockErr = Join-Path $softlockEvidence "$stage.stderr.log"
    $softlockArgs = @('--headless','--path',('"' + $softlockProject + '"'),'--script',("res://tests/foundation/quality/softlock/" + $softlockScript))
    $softlockProcess = Start-Process -FilePath $Godot -ArgumentList $softlockArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $softlockOut -RedirectStandardError $softlockErr
    $softlockTimedOut = -not $softlockProcess.WaitForExit(60000)
    if ($softlockTimedOut) { $softlockProcess.Kill() }
    $softlockProcess.WaitForExit()
    $softlockText = [string](Get-Content -LiteralPath $softlockOut -Raw)
    $softlockErrors = [string](Get-Content -LiteralPath $softlockErr -Raw)
    $softlockCount = 0
    $softlockPattern = if ($stage -eq 'unit') { 'SOFTLOCK_UNIT checks=([1-9][0-9]*) failures=\[\]' } else { 'SOFTLOCK_INTEGRATION checks=([1-9][0-9]*) failures=\[\]' }
    if ($softlockText -match $softlockPattern) { $softlockCount = [int]$Matches[1] }
    $softlockMarker = if ($stage -eq 'unit') { $softlockText -match 'FOUNDATION_SOFTLOCK_ANALYSIS_PROVISIONAL_PASS' } else { $softlockText -match 'FOUNDATION_SOFTLOCK_ANALYSIS_PASS|DEPENDENCY_PENDING: REAL_3A_STATEGRAPH' }
    if ($stage -eq 'integration' -and $softlockText -match 'DEPENDENCY_PENDING: REAL_3A_STATEGRAPH') { $softlockPending = $true }
    if ($softlockTimedOut -or $softlockProcess.ExitCode -ne 0 -or $softlockCount -le 0 -or -not $softlockMarker -or -not [string]::IsNullOrWhiteSpace($softlockErrors) -or ($softlockText+$softlockErrors) -match 'SCRIPT ERROR:|ERROR:|FAIL:') { $softlockFailures += $stage }
    $softlockResults += [pscustomobject]@{stage=$stage;checks=$softlockCount;exit_code=$softlockProcess.ExitCode;timed_out=$softlockTimedOut;stdout=$softlockOut;stderr=$softlockErr}
    if ($stage -eq 'integration' -and -not $softlockPending) {
        $softlockEvidenceLine = @($softlockText -split '\r?\n' | Where-Object { $_.StartsWith('SOFTLOCK_REAL_EVIDENCE ') })
        if ($softlockEvidenceLine.Count -ne 1) { $softlockFailures += 'missing_real_graph_evidence' }
        else {
            $softlockGraphEvidence = @($softlockEvidenceLine[0].Substring(23) | ConvertFrom-Json)
            $softlockGraphEvidence | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath (Join-Path $softlockEvidence 'real-graphs.json') -Encoding utf8
            $softlockExpectedCases = @('initial_goal','no_goal','corridor','sink','cycle','multiple_goals','partial','custom_initial')
            if ($softlockGraphEvidence.Count -ne 8 -or @(Compare-Object $softlockExpectedCases @($softlockGraphEvidence.case)).Count -gt 0 -or @($softlockGraphEvidence | Where-Object source -NE 'REAL_3A_EXPLORER').Count -gt 0) { $softlockFailures += 'real_graph_case_coverage' }
        }
    }
    Write-Output (($softlockText -split '\r?\n' | Where-Object { -not $_.StartsWith('SOFTLOCK_REAL_EVIDENCE ') }) -join "`n")
}
$softlockReport = [pscustomobject]@{
    head=(& git -C $softlockProject rev-parse HEAD).Trim()
    branch=(& git -C $softlockProject branch --show-current).Trim()
    dependency_status=$(if ($softlockPending) { 'DEPENDENCY_PENDING: REAL_3A_STATEGRAPH' } else { 'REAL_3A_EXPLORER' })
    proof_scope=$(if ($softlockPending) { 'TEST_ONLY_GRAPH_FIXTURES_AND_CONTROLLED_VALIDATOR_DOUBLE' } else { 'REAL_3A_EXPLORER_PLUS_ALGORITHM_UNIT_FIXTURES' })
    analysis_budget=[pscustomobject]@{max_nodes=10000;max_edges=100000;max_runtime_ms=0}
    budget_test_variants='capacity below/exact size; controlled clock after validation, during reverse, at return; invalid budgets'
    dependencies=$softlockDependencies
    stages=$softlockResults
    real_graph_cases=$softlockGraphEvidence.Count
    checks=($softlockResults | Measure-Object -Property checks -Sum).Sum
    failures=@($softlockFailures)
}
$softlockReport | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $softlockEvidence 'results.json') -Encoding utf8
if ($softlockFailures.Count -gt 0) { throw "Softlock verification failed: $($softlockFailures -join ', '); see $softlockEvidence" }
if ($softlockPending) {
    Write-Output "FOUNDATION_SOFTLOCK_ANALYSIS_PROVISIONAL_PASS checks=$($softlockReport.checks) evidence=$softlockEvidence"
    Write-Output 'DEPENDENCY_PENDING: REAL_3A_STATEGRAPH'
} else {
    Write-Output "FOUNDATION_SOFTLOCK_ANALYSIS_PASS checks=$($softlockReport.checks) evidence=$softlockEvidence"
}
