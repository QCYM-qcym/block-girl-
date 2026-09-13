param(
    [string]$Godot = 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [string]$EvidenceName = ('full_' + (Get-Date -Format 'yyyyMMdd_HHmmss')),
    [switch]$Headless
)
$ErrorActionPreference = 'Stop'
if ($EvidenceName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Use a simple evidence folder name.' }
$fullProject = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$fullEvidence = Join-Path $fullProject ".godot/foundation-2-full/$EvidenceName"
if (Test-Path -LiteralPath $fullEvidence) { throw 'Preserving evidence: choose a fresh name.' }
New-Item -ItemType Directory -Path $fullEvidence -Force | Out-Null
$dependencies = @()
foreach ($dir in @('foundation','prototype/foundation','tools/foundation/level','tests/foundation/full_integration')) {
    Get-ChildItem -LiteralPath (Join-Path $fullProject $dir) -Recurse -File | Where-Object Extension -In @('.gd','.tscn','.ps1') | Sort-Object FullName | ForEach-Object {
        $dependencies += [pscustomobject]@{path=$_.FullName.Substring($fullProject.Length+1);sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
    }
}
$arguments = @('--path',('"'+$fullProject+'"'),'--script','res://tests/foundation/full_integration/test_full_integration.gd','--max-fps','60')
if ($Headless) { $arguments += '--headless' }
$arguments += @('--',('--evidence-dir="'+$fullEvidence+'"'))
$stdout = Join-Path $fullEvidence 'e2e.stdout.log'
$stderr = Join-Path $fullEvidence 'e2e.stderr.log'
$process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$timedOut = -not $process.WaitForExit(60000)
if ($timedOut) { $process.Kill(); $process.WaitForExit() }
$process.WaitForExit()
$outText = Get-Content -LiteralPath $stdout -Raw
$errText = Get-Content -LiteralPath $stderr -Raw
$passed = -not $timedOut -and $process.ExitCode -eq 0 -and $outText -match 'FOUNDATION_2_E2E_PASS checks=[1-9][0-9]*' -and [string]::IsNullOrWhiteSpace($errText) -and ($outText+$errText) -notmatch 'SCRIPT ERROR:|ERROR:|FAIL:'
[pscustomobject]@{head=(& git -C $fullProject rev-parse HEAD);passed=$passed;exit_code=$process.ExitCode;timed_out=$timedOut;headless=[bool]$Headless;dependencies=$dependencies;stdout=$stdout;stderr=$stderr} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $fullEvidence 'execution.json') -Encoding utf8
Write-Output $outText
if (-not $passed) { throw "Full integration failed: $errText (evidence $fullEvidence)" }
$report = Get-Content -LiteralPath (Join-Path $fullEvidence 'results.json') -Raw | ConvertFrom-Json
if ($report.failures.Count -ne 0 -or $report.checks -le 0 -or (-not $Headless -and $report.display -eq 'headless')) { throw 'Missing or invalid real graphical report.' }
Write-Output "FOUNDATION_2_FULL_VALIDATION_PASS checks=$($report.checks) evidence=$fullEvidence"
