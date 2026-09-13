extends RefCounted
var moved:=false
var shifted:=false
var rotated:=false
var rotation_hint_seen:=false
var text: String="W A S D"
var alpha:=1.0
func reset() -> void:
	moved=false; shifted=false; rotated=false; rotation_hint_seen=false
	text="W A S D"; alpha=1.0
func update(mover,view,delta: float,rotation_committed: bool) -> void:
	if mover.moves>0: moved=true
	if mover.world==1: shifted=true
	if rotation_hint_seen and rotation_committed: rotated=true
	var desired: String=""
	if not moved: desired="W A S D"
	elif not shifted and mover.cell==Vector2i(0,2): desired="Space"
	elif not rotated and mover.cell==Vector2i(3,0):
		desired="Q / E    ·    鼠标左右拖动"
		rotation_hint_seen=true
	if mover.phase=="complete": desired=""
	if desired!=text:
		alpha=move_toward(alpha,0,delta*4)
		if alpha==0: text=desired
	else: alpha=move_toward(alpha,1 if not text.is_empty() else 0,delta*4)
