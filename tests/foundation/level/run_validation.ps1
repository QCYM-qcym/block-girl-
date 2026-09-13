param(
    [string]$Godot = 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [string]$EvidenceName = ('level_baker_' + (Get-Date -Format 'yyyyMMdd_HHmmss')),
    [string]$ValidatorSourceRoot = 'E:/godot/worktrees/block-girl-foundation-validator'
)

$ErrorActionPreference = 'Stop'
if ($EvidenceName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'EvidenceName must be a simple folder name.' }
if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) { throw "Godot not found: $Godot" }

$sourceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
if (-not (Test-Path -LiteralPath $ValidatorSourceRoot -PathType Container)) {
    throw "Real FOUNDATION-2B source root is missing: $ValidatorSourceRoot"
}
$validatorRoot = (Resolve-Path -LiteralPath $ValidatorSourceRoot).Path
$requiredValidatorFiles = @(
    'foundation/validation/safety_queries.gd',
    'foundation/validation/safety_queries.gd.uid',
    'foundation/validation/static_validator.gd',
    'foundation/validation/static_validator.gd.uid',
    'foundation/validation/validation_types.gd',
    'foundation/validation/validation_types.gd.uid'
)
foreach ($relativePath in $requiredValidatorFiles) {
    $candidate = Join-Path $validatorRoot $relativePath
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "Real FOUNDATION-2B dependency is incomplete; required source file is missing: $candidate"
    }
}

$evidenceRoot = Join-Path $sourceRoot ".godot/foundation-2c/$EvidenceName"
if (Test-Path -LiteralPath $evidenceRoot) { throw 'Preserving existing evidence: choose a new EvidenceName.' }
$projectRoot = Join-Path $evidenceRoot 'project'
New-Item -ItemType Directory -Path $projectRoot -Force | Out-Null

$copiedFiles = [System.Collections.Generic.List[object]]::new()
function Copy-EvidenceFile([string]$Origin, [string]$SourceBase, [string]$RelativePath) {
    $source = Join-Path $SourceBase $RelativePath
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Required $Origin source file is missing: $source" }
    $destination = Join-Path $projectRoot $RelativePath
    $destinationParent = Split-Path -Parent $destination
    New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination
    $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
    $copyHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($sourceHash -cne $copyHash) { throw "Copied-source hash mismatch: $RelativePath" }
    $copiedFiles.Add([pscustomobject]@{
        origin = $Origin
        relative_path = $RelativePath.Replace('\', '/')
        source_path = $source
        source_sha256 = $sourceHash
        copy_sha256 = $copyHash
        equal = $true
    })
}

$ownFoundationDirectories = @('foundation/contracts', 'foundation/orientation', 'foundation/spatial', 'foundation/celestial', 'foundation/level')
foreach ($relativeDirectory in $ownFoundationDirectories) {
    $absoluteDirectory = Join-Path $sourceRoot $relativeDirectory
    if (-not (Test-Path -LiteralPath $absoluteDirectory -PathType Container)) { throw "Required FOUNDATION source directory is missing: $absoluteDirectory" }
    Get-ChildItem -LiteralPath $absoluteDirectory -File | Where-Object { $_.Name -match '\.gd(?:\.uid)?$' } | Sort-Object Name | ForEach-Object {
        Copy-EvidenceFile 'foundation-2c-worktree' $sourceRoot (Join-Path $relativeDirectory $_.Name)
    }
}
foreach ($relativeDirectory in @('tests/foundation/level', 'tools/foundation/level')) {
    $absoluteDirectory = Join-Path $sourceRoot $relativeDirectory
    Get-ChildItem -LiteralPath $absoluteDirectory -File | Sort-Object Name | ForEach-Object {
        Copy-EvidenceFile 'foundation-2c-worktree' $sourceRoot (Join-Path $relativeDirectory $_.Name)
    }
}
foreach ($relativePath in $requiredValidatorFiles) {
    Copy-EvidenceFile 'foundation-2b-validator-worktree' $validatorRoot $relativePath
}

$projectConfig = "; Minimal isolated FOUNDATION-2C validation project.`nconfig_version=5`n`n[application]`nconfig/name=`"FOUNDATION-2C Validation`"`n`n[rendering]`nrenderer/rendering_method=`"gl_compatibility`"`nrenderer/rendering_method.mobile=`"gl_compatibility`"`n"
[IO.File]::WriteAllText((Join-Path $projectRoot 'project.godot'), $projectConfig, [Text.UTF8Encoding]::new($false))
$publicationTest = @'
extends SceneTree
const Cli = preload("res://tools/foundation/level/bake_level.gd")

func _initialize() -> void:
	var directory := ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(directory)
	var temporary := directory.path_join("publication-candidate.tmp")
	var target := directory.path_join("publication-existing.level.json")
	for path in [temporary, target]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var candidate := FileAccess.open(temporary, FileAccess.WRITE)
	candidate.store_string("candidate")
	candidate = null
	var existing := FileAccess.open(target, FileAccess.WRITE)
	existing.store_string("preserve-me")
	existing = null
	var rejection: String = Cli._publish_without_overwrite(temporary, target)
	var preserved := FileAccess.get_file_as_string(target) == "preserve-me"
	var candidate_preserved := FileAccess.get_file_as_string(temporary) == "candidate"
	DirAccess.remove_absolute(temporary)
	DirAccess.remove_absolute(target)
	if rejection.is_empty() or not preserved or not candidate_preserved:
		printerr("FAIL: publication helper overwrote or consumed an existing target")
		quit(1)
		return
	print("FOUNDATION_LEVEL_PUBLICATION_TEST_PASS")
	quit(0)
'@
[IO.File]::WriteAllText((Join-Path $projectRoot 'tests/foundation/level/test_cli_publication.gd'), $publicationTest, [Text.UTF8Encoding]::new($false))
$validatorHead = (& git -C $validatorRoot rev-parse HEAD 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $validatorHead -notmatch '^[0-9a-fA-F]{40}$') { throw "Could not record real FOUNDATION-2B HEAD: $validatorHead" }
$manifest = [pscustomobject]@{
    foundation_2b_head = $validatorHead.ToLowerInvariant()
    source_copy_equal = -not ($copiedFiles | Where-Object { -not $_.equal })
    files = @($copiedFiles)
}
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $evidenceRoot 'source_manifest.json') -Encoding utf8
[IO.File]::WriteAllText((Join-Path $evidenceRoot 'foundation_2b_head.txt'), $validatorHead.ToLowerInvariant(), [Text.UTF8Encoding]::new($false))

$results = [System.Collections.Generic.List[object]]::new()
function Save-Results {
    @($results) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $evidenceRoot 'results.json') -Encoding utf8
}
function Invoke-GodotStage([string]$Stage, [string[]]$Arguments, [int]$ExpectedExitCode, [string]$RequiredToken, [switch]$Negative) {
    $stdoutPath = Join-Path $evidenceRoot "$Stage.stdout.log"
    $stderrPath = Join-Path $evidenceRoot "$Stage.stderr.log"
    $process = Start-Process -FilePath $Godot -ArgumentList $Arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    if (-not $process.WaitForExit(60000)) {
        $process.Kill()
        $process.WaitForExit()
        $results.Add([pscustomobject]@{ stage=$Stage; exit_code=$null; expected_exit_code=$ExpectedExitCode; timed_out=$true; stdout=$stdoutPath; stderr=$stderrPath })
        Save-Results
        throw "$Stage timed out after 60 seconds; see $evidenceRoot"
    }
    $process.WaitForExit()
    $stdout = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw } else { '' }
    $stderr = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw } else { '' }
    $combined = $stdout + "`n" + $stderr
    $results.Add([pscustomobject]@{ stage=$Stage; exit_code=$process.ExitCode; expected_exit_code=$ExpectedExitCode; timed_out=$false; stdout=$stdoutPath; stderr=$stderrPath })
    Save-Results
    Write-Output $stdout
    if ($process.ExitCode -ne $ExpectedExitCode) { throw "$Stage exited $($process.ExitCode), expected $ExpectedExitCode; see $evidenceRoot" }
    if ($combined -match 'SCRIPT ERROR:|(^|\r?\n)ERROR:|(^|\r?\n)FAIL:|Unicode parsing error') { throw "$Stage emitted a Godot/script error or failure; see $evidenceRoot" }
    if ([string]::IsNullOrEmpty($RequiredToken) -or $combined -notmatch [regex]::Escape($RequiredToken)) { throw "$Stage did not emit required token '$RequiredToken'; see $evidenceRoot" }
    if ($Negative -and $combined -notmatch 'FOUNDATION_LEVEL_BAKE_ERROR') { throw "$Stage did not report the expected CLI rejection; see $evidenceRoot" }
}

$baseArguments = @('--headless', '--path', ('"' + $projectRoot + '"'))
$scenePath = 'res://tools/foundation/level/minimal_authoring.tscn'
$artifactRelative = 'artifacts/minimal.level.json'
$artifactPath = Join-Path $projectRoot $artifactRelative

# All success paths run before deliberate rejection cases.
Invoke-GodotStage 'codec_suite' ($baseArguments + @('--script', 'res://tests/foundation/level/test_level_codec.gd')) 0 'FOUNDATION_LEVEL_CODEC_PASS'
Invoke-GodotStage 'baker_suite' ($baseArguments + @('--script', 'res://tests/foundation/level/test_level_baker.gd')) 0 'FOUNDATION_LEVEL_BAKER_TEST_PASS'
Invoke-GodotStage 'publication_helper' ($baseArguments + @('--script', 'res://tests/foundation/level/test_cli_publication.gd')) 0 'FOUNDATION_LEVEL_PUBLICATION_TEST_PASS'
Invoke-GodotStage 'cli_success' ($baseArguments + @('--script', 'res://tools/foundation/level/bake_level.gd', '--', "--scene=$scenePath", "--output=res://$artifactRelative")) 0 'FOUNDATION_LEVEL_BAKE_PASS'
if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) { throw 'CLI success did not create its declared artifact.' }
Invoke-GodotStage 'artifact_verify' ($baseArguments + @('--script', 'res://tests/foundation/level/test_level_baker.gd', '--', "--artifact=res://$artifactRelative")) 0 'FOUNDATION_LEVEL_BAKER_TEST_PASS'

$artifactBefore = [IO.File]::ReadAllBytes($artifactPath)
Invoke-GodotStage 'reject_existing_output' ($baseArguments + @('--script', 'res://tools/foundation/level/bake_level.gd', '--', "--scene=$scenePath", "--output=res://$artifactRelative")) 1 'FOUNDATION_LEVEL_BAKE_ERROR' -Negative
if (-not ([Linq.Enumerable]::SequenceEqual([byte[]]$artifactBefore, [byte[]][IO.File]::ReadAllBytes($artifactPath)))) { throw 'Existing-output rejection changed the original artifact.' }

$invalidSceneOutput = Join-Path $projectRoot 'artifacts/invalid-scene.level.json'
Invoke-GodotStage 'reject_invalid_scene' ($baseArguments + @('--script', 'res://tools/foundation/level/bake_level.gd', '--', '--scene=res://tools/foundation/level/missing.tscn', '--output=res://artifacts/invalid-scene.level.json')) 1 'FOUNDATION_LEVEL_BAKE_ERROR' -Negative
if (Test-Path -LiteralPath $invalidSceneOutput) { throw 'Invalid scene rejection created an output file.' }

$badOutput = Join-Path $projectRoot 'artifacts/relative-output.level.json'
Invoke-GodotStage 'reject_bad_output' ($baseArguments + @('--script', 'res://tools/foundation/level/bake_level.gd', '--', "--scene=$scenePath", '--output=artifacts/relative-output.level.json')) 1 'FOUNDATION_LEVEL_BAKE_ERROR' -Negative
if (Test-Path -LiteralPath $badOutput) { throw 'Bad output path rejection created an output file.' }

$malformedOutput = Join-Path $projectRoot 'artifacts/malformed.level.json'
Invoke-GodotStage 'reject_malformed_arguments' ($baseArguments + @('--script', 'res://tools/foundation/level/bake_level.gd', '--', "--scene=$scenePath", '--output=res://artifacts/malformed.level.json', '--unexpected=value')) 1 'FOUNDATION_LEVEL_BAKE_ERROR' -Negative
if (Test-Path -LiteralPath $malformedOutput) { throw 'Malformed arguments created an output file.' }

$badSceneRelative = 'artifacts/validator-rejected.tscn'
$badScenePath = Join-Path $projectRoot $badSceneRelative
$sceneText = [IO.File]::ReadAllText((Join-Path $projectRoot 'tools/foundation/level/minimal_authoring.tscn'))
$slotNeedle = "[node name=`"A`" type=`"Node3D`" parent=`"Slots`"]`nposition = Vector3(0,5,0)"
$badSceneText = $sceneText.Replace($slotNeedle, "[node name=`"A`" type=`"Node3D`" parent=`"Slots`"]`nposition = Vector3(0,0,0)")
if ($badSceneText -ceq $sceneText) { throw 'Could not create the isolated Validator-rejection fixture.' }
New-Item -ItemType Directory -Path (Split-Path -Parent $badScenePath) -Force | Out-Null
[IO.File]::WriteAllText($badScenePath, $badSceneText, [Text.UTF8Encoding]::new($false))
$rejectedBakeOutput = Join-Path $projectRoot 'artifacts/rejected-bake.level.json'
Invoke-GodotStage 'reject_invalid_bake' ($baseArguments + @('--script', 'res://tools/foundation/level/bake_level.gd', '--', "--scene=res://$badSceneRelative", '--output=res://artifacts/rejected-bake.level.json')) 1 'FOUNDATION_LEVEL_BAKE_ERROR Bake failed' -Negative
if (Test-Path -LiteralPath $rejectedBakeOutput) { throw 'Validator rejection created an output file.' }

Write-Output "FOUNDATION_LEVEL_BAKER_PROTOTYPE_PASS evidence=$evidenceRoot"
Write-Output "FOUNDATION_LEVEL_BAKER_PASS evidence=$evidenceRoot"
Write-Output 'CONTRACT_MISMATCH: NONE'
