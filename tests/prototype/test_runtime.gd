extends SceneTree

var game
var checks := 0
var failures: Array[String] = []
var frames: Dictionary = {}
var evidence := "res://tests/prototype/evidence/run_01"
var shots: Array[String] = []
var started := Time.get_ticks_msec()

func _initialize() -> void:
	if not ResourceLoader.exists("res://prototype/puzzle_01.tscn"):
		printerr("FAIL: Independent playable scene exists and can receive player input")
		quit(1)
		return
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	game = load("res://prototype/puzzle_01.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.state.cell == Vector2i(1,9), "starts at Surface spawn")
	check(game.board.cell_position(Vector2i.ZERO) == Vector2.ZERO, "normalized TileMap origin")
	check(game.board.cell_position(Vector2i(1,0)) == Vector2(16,8), "accepted tile axis +X")
	check(game.board.cell_position(Vector2i(0,1)) == Vector2(-16,8), "accepted tile axis +Z")
	await shot("01_surface_start")
	await key(KEY_A)
	check(game.state.cell == Vector2i(1,9) and game.message_label.text.contains("落脚"), "void gives visible feedback")
	await key(KEY_D, true)
	check(game.state.phase == "idle", "OS repeat event ignored")
	await key(KEY_D)
	await delay(0.10)
	check(game.player.body.animation == "roll_right" and game.state.cell == Vector2i(1,9), "real roll before cell commit")
	await shot("02_surface_roll")
	await key(KEY_SPACE)
	await key(KEY_D)
	await settle()
	check(game.state.cell == Vector2i(2,9) and game.state.world == 0, "rapid keys cannot overlap a roll")
	await move(KEY_A)
	await move(KEY_W)
	await move(KEY_S)
	# Reset mid-roll and mid-switch: wait beyond the old animation before checking.
	await key(KEY_D)
	await delay(0.1)
	await key(KEY_R)
	await delay(0.7)
	check_spawn("Reset during roll")
	await key(KEY_SPACE)
	await delay(0.15)
	await key(KEY_R)
	await delay(0.7)
	check_spawn("Reset during switch")
	await move(KEY_D,5)
	await move(KEY_W)
	await key(KEY_W)
	check(game.state.cell == Vector2i(6,8), "Surface approach gap blocks input")
	await change_world()
	check(game.state.cell == Vector2i(6,8) and game.state.world == 1, "same-coordinate switch and skin commit")
	check(game.player.body.sprite_frames.resource_path.ends_with("mortis_sprite_frames.tres"), "Mortis frames selected")
	await shot("03_inner_route")
	await move(KEY_W)
	await key(KEY_SPACE)
	check(game.state.world == 1 and game.state.phase == "idle" and game.message_label.text.contains("无法切换"), "unsafe switch feedback and unchanged state")
	await shot("04_switch_rejected")
	# Reach the closed door through the actual route before pressing the plate.
	await move(KEY_W)
	await move(KEY_D,4)
	await change_world()
	await move(KEY_W,2)
	await key(KEY_W)
	check(game.state.cell == Vector2i(10,4) and game.board.door.state == "closed", "closed gate cannot be crossed")
	await shot("05_closed_gate")
	await key(KEY_R)
	await reach_plate_approach()
	await key(KEY_W)
	await wait_phase("pressing")
	check(game.board.plate.state == "pressed", "plate pressed uses accepted visual")
	await shot("06_plate_pressed")
	await key(KEY_R)
	await delay(1.0)
	check_spawn("Reset during plate interaction")
	await reach_plate_approach()
	await key(KEY_W)
	await settle()
	check(game.state.plate_latched and game.board.plate.state == "active", "plate latches after interaction")
	check(not game.state.door_open and game.board.door.state == "opening", "door opening remains logically blocked")
	await key(KEY_R)
	await delay(0.7)
	check_spawn("Reset during door opening")
	await reach_plate_approach()
	await move(KEY_W)
	await delay(0.45)
	check(game.state.door_open and game.board.door.state == "open", "door animation commits passage")
	check(game.board.door.get_node("Shutter/Shape").disabled and game.board.goal.state == "ready", "accepted shutter collider opens and exit becomes ready")
	await shot("07_plate_latched")
	await return_to_exit()
	await key(KEY_W)
	await wait_phase("completing")
	check(game.board.goal.state == "complete", "exit activates accepted completion animation")
	await key(KEY_R)
	await delay(1.1)
	check_spawn("Reset during exit completion")
	# A fresh end-to-end solve, with no state injection.
	await reach_plate_approach()
	await move(KEY_W)
	await delay(0.45)
	await return_to_exit()
	await move(KEY_W)
	check(game.state.phase == "complete" and game.complete_label.visible and game.board.goal.state == "completed", "full playable Puzzle Complete")
	await delay(0.7)
	check(game.player.action == "" and frames.get("mutsumi/puzzle_complete", {}).size() == 6, "all six player completion frames finish")
	await shot("09_complete")
	await key(KEY_D)
	await key(KEY_SPACE)
	check(game.state.cell == Vector2i(10,1) and game.state.world == 0, "completed input locked")
	await key(KEY_R)
	await delay(0.8)
	check_spawn("Reset after completion")
	await shot("10_reset")
	for size in [Vector2i(960,640), Vector2i(1600,1000)]:
		root.size = size
		await delay(0.2)
		check(game.board.scale.x == floorf(game.board.scale.x), "integer board scale %s" % size)
		await shot("size_%dx%d" % [size.x,size.y])
	for skin in ["mutsumi", "mortis"]:
		for animation in ["roll_left", "roll_right", "roll_forward", "roll_backward", "world_switch"]:
			var id: String = skin + "/" + animation
			check(frames.get(id, {}).size() == 6, "all 6 real frames observed " + id)
	var report := {"checks": checks, "failures": failures, "animation_frames": frames, "screenshots": shots, "elapsed_seconds": (Time.get_ticks_msec()-started)/1000.0, "godot": Engine.get_version_info(), "display_server": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(), "gpu": RenderingServer.get_video_adapter_name()}
	FileAccess.open(evidence.path_join("runtime_report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RUNTIME_TESTS: ", checks, " checks; failures=", failures)
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func sample() -> void:
	var body: AnimatedSprite2D = game.player.body
	var skin := "mortis" if body.sprite_frames.resource_path.contains("mortis") else "mutsumi"
	var id := skin + "/" + str(body.animation)
	if not frames.has(id): frames[id] = {}
	frames[id][str(body.frame)] = true
	check(game.player.position == game.player.position.round(), "player native pixel alignment")

func delay(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		await process_frame
		sample()

func key(code: int, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)

func settle() -> void:
	var until := Time.get_ticks_msec()+4500
	while game.state.phase not in ["idle", "complete"] and Time.get_ticks_msec() < until:
		await process_frame
		sample()
	check(game.state.phase in ["idle", "complete"], "action completes before timeout: " + game.state.phase)

func wait_phase(phase: String) -> void:
	var until := Time.get_ticks_msec()+2000
	while game.state.phase != phase and Time.get_ticks_msec() < until:
		await process_frame
		sample()
	check(game.state.phase == phase, "arrives at phase " + phase)

func move(code: int, count: int = 1) -> void:
	for i in count:
		await key(code)
		await settle()

func change_world() -> void:
	await key(KEY_SPACE)
	await settle()

func reach_plate_approach() -> void:
	await move(KEY_D,5)
	await move(KEY_W)
	await change_world()
	await move(KEY_W,5)
	await move(KEY_A,4)
	await move(KEY_W)
	check(game.state.cell == Vector2i(2,2), "walked to plate approach")

func return_to_exit() -> void:
	await move(KEY_S,2)
	check(game.state.plate_latched, "leaving plate preserves latch")
	await move(KEY_D,4)
	await move(KEY_S,3)
	await move(KEY_D,4)
	await change_world()
	await move(KEY_W,4)
	check(game.state.cell == Vector2i(10,2), "walked through open door to exit approach")
	await shot("08_open_gate_passed")

func check_spawn(label: String) -> void:
	check(game.state.cell == Vector2i(1,9) and game.state.world == 0 and game.state.phase == "idle" and not game.state.plate_latched and not game.state.door_open and game.state.moves == 0 and game.state.switches == 0, label+" restores model")
	check(game.player.position == game.board.cell_position(Vector2i(1,9)) and game.player.body.sprite_frames.resource_path.contains("mutsumi") and game.player.action == "", label+" restores player")
	check(game.board.door.state == "closed" and game.board.goal.state == "locked" and game.board.plate.state == "idle" and not game.complete_label.visible, label+" restores mechanisms and HUD")

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path := evidence.path_join(name+".png")
	check(root.get_texture().get_image().save_png(path) == OK, "GPU screenshot " + name)
	shots.append(path)
