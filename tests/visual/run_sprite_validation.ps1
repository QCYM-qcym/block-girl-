param(
    [switch]$Auto,
    [string]$GodotPath = 'D:\APP\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw "Godot executable not found: $GodotPath" }
$spriteProject = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$spriteArguments = @('--path', ('"' + $spriteProject + '"'), '--max-fps', '60', 'res://tests/visual/sprite_runtime_test.tscn')
if ($Auto) {
    $spriteEvidence = Join-Path $PSScriptRoot ('evidence\run_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
    $spriteArguments += @('--', '--auto', ('"--evidence-dir=' + $spriteEvidence + '"'))
}
# This is the visible, interactive asset validation window requested by the user.
Start-Process -FilePath $GodotPath -ArgumentList $spriteArguments -WindowStyle Normal
