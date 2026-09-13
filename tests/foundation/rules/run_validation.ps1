param(
    [string]$Godot = 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [string]$EvidenceName = ('run_' + (Get-Date -Format 'yyyyMMdd_HHmmss')),
    [switch]$UnitDouble
)
$ErrorActionPreference = 'Stop'
if ($EvidenceName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Use a simple evidence folder name.' }
$kernelProject = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$kernelEvidence = Join-Path $kernelProject ".godot/foundation-2a-validation/$EvidenceName"
if (Test-Path -LiteralPath $kernelEvidence) { throw 'Preserving existing evidence: choose a new EvidenceName.' }
New-Item -ItemType Directory -Path $kernelEvidence -Force | Out-Null
$kernelSafety = Join-Path $kernelProject 'foundation/validation/safety_queries.gd'
$kernelMode = if ($UnitDouble) { 'UNIT_DOUBLE_ONLY' } else { 'REAL_SAFETY' }
$kernelExtraArgs = @()
if ($UnitDouble) {
    # Test-only shadow copies link the real rules code to a controllable test double.
    # Production files always preload the actual 2B dependency; no fallback exists.
    $kernelShadow = Join-Path $kernelEvidence 'rules'
    New-Item -ItemType Directory -Path $kernelShadow -Force | Out-Null
    $kernelShadowResource = "res://.godot/foundation-2a-validation/$EvidenceName/rules/"
    foreach ($kernelFile in (Get-ChildItem -LiteralPath (Join-Path $kernelProject 'foundation/rules') -Filter '*.gd' -File)) {
        $kernelText = [System.IO.File]::ReadAllText($kernelFile.FullName)
        $kernelText = $kernelText.Replace('res://foundation/rules/', $kernelShadowResource)
        $kernelText = $kernelText.Replace('res://foundation/validation/safety_queries.gd', 'res://tests/foundation/rules/safety_double.gd')
        if ($kernelFile.Name -eq 'puzzle_rule_kernel.gd') {
            $kernelText = $kernelText.Replace(('const Derived = preload("' + $kernelShadowResource + 'derived_state_resolver.gd")'), 'const Derived = preload("res://tests/foundation/rules/kernel_fixture.gd")')
        }
        [System.IO.File]::WriteAllText((Join-Path $kernelShadow $kernelFile.Name), $kernelText, [System.Text.UTF8Encoding]::new($false))
    }
    $kernelExtraArgs = @('--', "--rules-root=$kernelShadowResource")
} elseif (-not (Test-Path -LiteralPath $kernelSafety)) {
    'REAL_SAFETY_DEPENDENCY_MISSING: foundation/validation/safety_queries.gd' | Set-Content -LiteralPath (Join-Path $kernelEvidence 'dependency.txt')
    throw 'Formal 2B Safety missing. Use -UnitDouble only for unit tests; final PASS is blocked.'
}
$kernelResults = @()
foreach ($kernelSuite in @('test_rule_kernel','test_busy_transition')) {
    $kernelOut = Join-Path $kernelEvidence "$kernelSuite.stdout.log"
    $kernelErr = Join-Path $kernelEvidence "$kernelSuite.stderr.log"
    $kernelArgs = @('--headless', '--path', ('"' + $kernelProject + '"'), '--script', "res://tests/foundation/rules/$kernelSuite.gd") + $kernelExtraArgs
    $kernelProcess = Start-Process -FilePath $Godot -ArgumentList $kernelArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $kernelOut -RedirectStandardError $kernelErr
    if (-not $kernelProcess.WaitForExit(60000)) {
        $kernelProcess.Kill()
        $kernelProcess.WaitForExit()
        throw "$kernelSuite timed out after 60 seconds; evidence preserved at $kernelEvidence"
    }
    $kernelProcess.WaitForExit()
    $kernelOutput = Get-Content -LiteralPath $kernelOut -Raw
    $kernelErrors = Get-Content -LiteralPath $kernelErr -Raw
    $kernelExpected = if ($UnitDouble) { 'UNIT_TESTS_WITH_DOUBLE_PASS' } elseif ($kernelSuite -eq 'test_rule_kernel') { 'RULE_KERNEL_REAL_SUITE_PASS' } else { 'BUSY_TRANSITION_REAL_SUITE_PASS' }
    $kernelCount = if ($kernelOutput -match 'checks=(\d+) failures=\[\]') { [int]$Matches[1] } else { 0 }
    $kernelResults += [pscustomobject]@{suite=$kernelSuite; mode=$kernelMode; checks=$kernelCount; exit_code=$kernelProcess.ExitCode; stdout=$kernelOut; stderr=$kernelErr}
    $kernelResults | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $kernelEvidence 'results.json') -Encoding utf8
    Write-Output $kernelOutput
    if ($kernelProcess.ExitCode -ne 0 -or $kernelCount -le 0 -or $kernelOutput -notmatch $kernelExpected -or ($kernelOutput + $kernelErrors) -match 'SCRIPT ERROR:|ERROR:|FAIL:') {
        throw "$kernelSuite failed: $kernelErrors"
    }
}
$kernelTotal = ($kernelResults | Measure-Object -Property checks -Sum).Sum
Write-Output "$kernelMode suites passed: $kernelTotal assertions; $kernelEvidence"
# Final FOUNDATION_RULE_KERNEL_PASS additionally requires first-wave regression,
# ownership review and real Safety. This unit wrapper never emits that token.
