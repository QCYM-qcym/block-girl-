extends "res://production/mechanisms/mechanism_visual.gd"
signal translated(delta: Vector2)
signal arrived(at: Vector2)
var start = Vector2.ZERO
var target = Vector2.ZERO
var elapsed = 0.0
var duration = 0.8
func move_to(destination: Vector2, seconds: float = 0.8) -> bool:
	if state == "moving" or position != position.round() or destination != destination.round(): return false
	var delta = destination - position
	var cell = Vector2((delta.x / 16.0 + delta.y / 8.0)/2.0,(delta.y / 8.0 - delta.x / 16.0)/2.0)
	if not cell.is_equal_approx(cell.round()): return false
	start = position
	target = destination
	duration = maxf(seconds,0.1)
	elapsed = 0.0
	set_state("moving")
	return true
func _physics_process(delta: float) -> void:
	if state != "moving": return
	elapsed += delta
	var next = start.lerp(target,minf(elapsed/duration,1.0)).round()
	var movement = next-position
	position = next
	translated.emit(movement)
	if elapsed >= duration:
		set_state("arrived")
		arrived.emit(position)
