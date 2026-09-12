extends SceneTree
var game
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	game = load("res://prototype/puzzle_01.tscn").instantiate()
	root.add_child(game)
	await process_frame
	# Windows Computer Use supplied D keycode but an unmapped Tab scancode.
	# Accessibility/remote input must still reach the normal player controller.
	var event := InputEventKey.new()
	event.physical_keycode = KEY_TAB
	event.keycode = KEY_D
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	if game.state.phase != "moving":
		printerr("FAIL: recognized logical key must work when physical key is unmapped")
		quit(1)
		return
	await create_timer(0.5).timeout
	if game.state.cell != Vector2i(2,9):
		printerr("FAIL: fallback D must move one tile")
		quit(1)
		return
	print("INPUT_TESTS: logical fallback moves exactly one tile; PASS")
	quit()
