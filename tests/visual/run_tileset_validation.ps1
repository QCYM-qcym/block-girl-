param([switch]$Auto,[string]$EvidenceName='manual')
$tileProject=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$tileEngine='D:\APP\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
$tileArgs=@('--path',('"'+$tileProject+'"'),'--max-fps','60','res://tests/visual/tileset_runtime_test.tscn')
if($Auto){$tileArgs+=@('--','--auto',('--evidence-dir="'+$PSScriptRoot+'/tileset_evidence/'+$EvidenceName+'"'))}
Start-Process -FilePath $tileEngine -ArgumentList $tileArgs -WindowStyle Normal
