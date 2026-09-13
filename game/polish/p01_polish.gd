extends Node
const Audio=preload("res://game/polish/p01_audio.gd")
const Feedback=preload("res://game/polish/p01_feedback.gd")
var audio=Audio.new()
var feedback=Feedback.new()
var game
var previous: Dictionary={}
func bind(level) -> void:
	game=level
	add_child(audio)
	game.board.add_child(feedback); feedback.bind(game)
	reset()
func snapshot() -> Dictionary:
	return {"phase":game.mover.phase,"moves":game.mover.moves,"world":game.mover.world,"view":game.view.current,"link":game.graph.link.active,"plate":game.graph.plate_pressed,"door":game.graph.door_open,"complete":game.graph.complete}
func tick(delta: float) -> void:
	var current:=snapshot()
	var landed: bool=current.moves!=previous.moves
	if landed:
		audio.play("land"); feedback.land_flash=0.16
	if current.phase=="roll" and (previous.phase!="roll" or landed): audio.play("roll")
	if current.phase=="shift" and previous.phase!="shift": audio.play("shift_inner" if current.world==0 else "shift_surface")
	if current.view!=previous.view: audio.play("rotate")
	if current.link!=previous.link:
		audio.play("link_on" if current.link else "link_off"); feedback.link_flash=0.5
	if current.plate and not previous.plate:
		audio.play("plate"); feedback.plate_flash=0.35
	if current.door!=previous.door: audio.play("door_open" if current.door else "door_close")
	if current.world==0 and previous.world!=0: audio.play("exit_ready")
	if current.complete and not previous.complete: audio.play("complete")
	feedback.tick(delta,current.world!=previous.world)
	audio.tick(delta,current.world,current.complete)
	game.completion.tick(delta,current.complete)
	previous=current
func reset() -> void:
	previous=snapshot()
	audio.reset(game.mover.world); feedback.reset()
	game.completion.reset(); game.hint_label.reset()
func set_fx_enabled(value: bool) -> void:
	feedback.enabled=value
	if not value: feedback.reset()
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode==KEY_M:
		AudioServer.set_bus_mute(0,not AudioServer.is_bus_mute(0))
		get_viewport().set_input_as_handled()
	elif event.keycode==KEY_F4:
		set_fx_enabled(not feedback.enabled)
		get_viewport().set_input_as_handled()
