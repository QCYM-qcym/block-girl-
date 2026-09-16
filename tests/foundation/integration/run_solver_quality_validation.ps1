param(
    [string]$Godot = 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [string]$EvidenceName = ('chain_' + (Get-Date -Format 'yyyyMMdd_HHmmss')),
    [switch]$Headless
)
$ErrorActionPreference = 'Stop'
if ($EvidenceName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Use a simple evidence folder name.' }
$chainRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$chainEvidence = Join-Path $chainRoot ".godot/foundation-3-final/$EvidenceName"
if (Test-Path -LiteralPath $chainEvidence) { throw 'Preserving evidence: choose a fresh name.' }
New-Item -ItemType Directory -Path $chainEvidence -Force | Out-Null
$dependencies = @()
foreach ($directory in @('foundation','tests/foundation/integration','tests/foundation/quality','tests/foundation/parity','tests/foundation/rules','tests/foundation/level','tools/foundation/level')) {
    Get-ChildItem -LiteralPath (Join-Path $chainRoot $directory) -Recurse -File |
        Where-Object Extension -In @('.gd','.ps1','.tscn') | Sort-Object FullName | ForEach-Object {
            $dependencies += [pscustomobject]@{path=$_.FullName.Substring($chainRoot.Length+1);sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
        }
}
$arguments = @('--path',('"'+$chainRoot+'"'),'--script','res://tests/foundation/integration/test_solver_quality_integration.gd','--max-fps','60')
if ($Headless) { $arguments += '--headless' }
$arguments += @('--',('--evidence-dir="'+$chainEvidence+'"'))
$stdout = Join-Path $chainEvidence 'chain.stdout.log'
$stderr = Join-Path $chainEvidence 'chain.stderr.log'
$watch = [Diagnostics.Stopwatch]::StartNew()
$process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$timedOut = -not $process.WaitForExit(60000)
if ($timedOut) { $process.Kill(); $process.WaitForExit() }
$process.WaitForExit()
$watch.Stop()
$outText = [IO.File]::ReadAllText($stdout)
$errText = [IO.File]::ReadAllText($stderr)
$passed = -not $timedOut -and $process.ExitCode -eq 0 -and $outText -match 'FOUNDATION_3_CHAIN_PASS checks=[1-9][0-9]*' -and [string]::IsNullOrWhiteSpace($errText)
$report = $null
if (Test-Path -LiteralPath (Join-Path $chainEvidence 'chain.json')) {
    $report = Get-Content -LiteralPath (Join-Path $chainEvidence 'chain.json') -Raw | ConvertFrom-Json
    $passed = $passed -and $report.checks -gt 0 -and $report.failures.Count -eq 0 -and $report.cases.Count -eq 18 -and ($Headless -or $report.display -ne 'headless')
} else { $passed = $false }
foreach ($dependency in $dependencies) {
    if ((Get-FileHash -LiteralPath (Join-Path $chainRoot $dependency.path) -Algorithm SHA256).Hash -ne $dependency.sha256) { $passed = $false }
}
[pscustomobject]@{head=(& git -C $chainRoot rev-parse HEAD);passed=$passed;exit_code=$process.ExitCode;timed_out=$timedOut;headless=[bool]$Headless;elapsed_seconds=$watch.Elapsed.TotalSeconds;arguments=$arguments;checks=$report.checks;failures=$report.failures;dependencies=$dependencies} |
    ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $chainEvidence 'execution.json') -Encoding utf8
Write-Output $outText
if (-not $passed) { throw "Final chain failed: $errText (evidence $chainEvidence)" }
Write-Output "FOUNDATION_3_CROSS_MODULE_PASS checks=$($report.checks) evidence=$chainEvidence"
