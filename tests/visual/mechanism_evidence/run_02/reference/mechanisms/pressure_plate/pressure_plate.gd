extends "res://production/mechanisms/mechanism_visual.gd"
signal occupancy_changed(count: int)
var occupants: Dictionary = {}
var activated = false
func _ready() -> void:
	super._ready()
	$Trigger.body_entered.connect(_enter)
	$Trigger.body_exited.connect(_exit)
func _enter(body: Node2D) -> void:
	occupants[body.get_instance_id()] = true
	_refresh()
func _exit(body: Node2D) -> void:
	occupants.erase(body.get_instance_id())
	_refresh()
func set_active(value: bool) -> void:
	activated = value
	_refresh()
func _refresh() -> void:
	set_state("active" if activated else ("idle" if occupants.is_empty() else "pressed"))
	occupancy_changed.emit(occupants.size())
