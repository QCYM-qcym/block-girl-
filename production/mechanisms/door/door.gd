extends "res://production/mechanisms/mechanism_visual.gd"
signal passage_changed(open: bool)
func initial_state() -> String: return "closed"
func _ready() -> void:
	super._ready()
	visual.animation_finished.connect(_finished)
func set_open(value: bool) -> void:
	if value and state in ["open","opening"]: return
	if not value and state in ["closed","closing"]: return
	$Shutter/Shape.set_deferred("disabled",false)
	set_state("opening" if value else "closing")
func _finished() -> void:
	if state == "opening":
		$Shutter/Shape.set_deferred("disabled",true)
		set_state("open")
		passage_changed.emit(true)
	elif state == "closing":
		set_state("closed")
		passage_changed.emit(false)
