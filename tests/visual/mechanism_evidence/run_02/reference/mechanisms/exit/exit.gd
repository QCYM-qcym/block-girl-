extends "res://production/mechanisms/mechanism_visual.gd"
signal activated
signal completed
func initial_state() -> String: return "locked"
func _ready() -> void:
	super._ready()
	$Trigger.body_entered.connect(_enter)
	visual.animation_finished.connect(_finished)
func set_ready(value: bool) -> void:
	if state in ["active","complete","completed"]: return
	set_state("ready" if value else "locked")
func _enter(_body: Node2D) -> void:
	if state == "ready":
		set_state("active")
		activated.emit()
func complete_goal() -> bool:
	if state != "active": return false
	set_state("complete")
	return true
func _finished() -> void:
	if state == "complete":
		set_state("completed")
		completed.emit()
