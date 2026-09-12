param([switch]$Auto,[string]$EvidenceName='manual')
$mechanismProject=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$mechanismArgs=@('--path',('"'+$mechanismProject+'"'),'--max-fps','60','res://tests/visual/mechanism_runtime_test.tscn')
if($Auto){$mechanismArgs+=@('--','--auto',('--evidence-dir="'+$PSScriptRoot+'/mechanism_evidence/'+$EvidenceName+'"'))}
Start-Process -FilePath 'D:\APP\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' -ArgumentList $mechanismArgs -WindowStyle Normal
