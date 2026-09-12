extends "res://production/mechanisms/mechanism_visual.gd"
signal orientation_changed(value: int)
var orientation = 0
var pending = 0
func initial_state() -> String: return "orientation_a"
func _ready() -> void:
	super._ready()
	visual.animation_finished.connect(_finished)
func rotate_to(value: int) -> bool:
	if value not in [0,1] or state.begins_with("rotating") or value == orientation: return false
	pending = value
	$Support/Shape.set_deferred("disabled",true)
	$Trigger/Shape.set_deferred("disabled",true)
	set_state("rotating" if value == 1 else "rotating_back")
	return true
func _finished() -> void:
	if not state.begins_with("rotating"): return
	orientation = pending
	var points = PackedVector2Array([Vector2(-4,-6),Vector2(12,2),Vector2(4,6),Vector2(-12,-2)]) if orientation == 0 else PackedVector2Array([Vector2(4,-6),Vector2(12,-2),Vector2(-4,6),Vector2(-12,2)])
	for shape in [$Support/Shape,$Trigger/Shape]:
		shape.set_deferred("polygon",points)
		shape.set_deferred("disabled",false)
	set_state("orientation_a" if orientation == 0 else "orientation_b")
	orientation_changed.emit(orientation)
