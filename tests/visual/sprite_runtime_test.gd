extends Node2D
## Isolated asset QA harness. No gameplay, movement controller, or world state system.

const ASSET_ROOT = "res://production/sprites/"
const SKINS = ["mutsumi", "mortis"]
const BACKGROUND = Color("34414a")
const CASES = ["idle", "subtle_idle", "roll_left", "roll_right", "roll_forward", "roll_backward", "interaction", "world_switch_start", "world_switch_midpoint", "world_switch", "puzzle_complete"]
var resources: Array[SpriteFrames] = []
var bodies: Array[AnimatedSprite2D] = []
var shadows: Array[AnimatedSprite2D] = []
var placements: Array = []
var title: Label
var info: Label
var completed: Array = [false, false]
var finished_at: Array = [0.0, 0.0]
var observed: Array = [[], []]
var active_case = "idle"
var case_start = 0
var automatic = false
var output = ""
var failures: Array = []
var report: Dictionary = {}
var captures: Array = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--auto":
			automatic = true
		if arg.begins_with("--evidence-dir="):
			output = arg.trim_prefix("--evidence-dir=")
	if output.is_empty():
		output = ProjectSettings.globalize_path("res://tests/visual/evidence/manual")
	DirAccess.make_dir_recursive_absolute(output)
	get_window().title = "Sprite Runtime Validation | Godot " + str(Engine.get_version_info().string)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size = Vector2i.ZERO
	get_window().unresizable = true
	get_window().size = Vector2i(1280, 720)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for skin in SKINS:
		var frames = load(ASSET_ROOT + skin + "_sprite_frames.tres") as SpriteFrames
		if frames == null:
			push_error("Unable to load SpriteFrames: " + skin)
			get_tree().quit(2)
			return
		resources.append(frames)
	_build_display()
	report = {
		"engine": Engine.get_version_info(),
		"display_server": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"project_default_texture_filter": ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"),
		"viewport_default_texture_filter": get_viewport().canvas_item_default_texture_filter,
		"test_texture_filter": texture_filter,
		"viewport": [get_viewport_rect().size.x, get_viewport_rect().size.y],
		"window_size": [get_window().size.x, get_window().size.y],
		"canvas_transform": str(get_viewport().get_canvas_transform()),
		"final_transform": str(get_viewport().get_final_transform()),
		"placements": placements,
		"imports": [],
		"cases": [],
		"switch_handoffs": [],
		"shadow": {},
		"failures": failures
	}
	_validate_loaded_resources()
	if automatic:
		_run_suite.call_deferred()
	else:
		_play("idle")

func _build_display() -> void:
	var background = ColorRect.new()
	background.name = "Background"
	background.color = BACKGROUND
	background.size = Vector2(1280, 720)
	background.z_index = -10
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	title = _label("SPRITE RUNTIME VALIDATION", Vector2(32, 22), 28)
	_label("Mutsumi / Mortis  |  integer scale 1x - 4x  |  fixed anchor + baseline", Vector2(32, 64), 18)
	for scale_value in range(1, 5):
		var group_x = 60 + (scale_value - 1) * 310
		_label(str(scale_value) + "x", Vector2(group_x, 123), 24)
		for skin in range(2):
			var anchor = Vector2(group_x + 60 + skin * 126, 290)
			_label(SKINS[skin].capitalize(), Vector2(anchor.x - 43, 170), 16)
			_add_pair(skin, scale_value, anchor, false)
	_label("8x inspection magnifier (not a substitute for the 1x-4x panels)", Vector2(32, 365), 18)
	_add_pair(0, 8, Vector2(400, 590), true)
	_add_pair(1, 8, Vector2(830, 590), true)
	info = _label("Loading...", Vector2(32, 625), 19)
	_label("1 idle | 2 subtle | 3 left | 4 right | 5 forward | 6 back | 7 interact | 8 complete | Space switch | S shadow", Vector2(32, 679), 16)

func _label(text: String, at: Vector2, size: int) -> Label:
	var label = Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	add_child(label)
	return label

func _add_pair(skin: int, scale_value: int, anchor: Vector2, magnifier: bool) -> void:
	var body = AnimatedSprite2D.new()
	body.name = SKINS[skin] + "_" + str(scale_value) + "x"
	body.sprite_frames = resources[skin]
	body.centered = true
	body.offset = Vector2(0, -9)
	body.position = anchor
	body.scale = Vector2.ONE * scale_value
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shadow = AnimatedSprite2D.new()
	shadow.sprite_frames = resources[skin]
	shadow.animation = &"shadow"
	shadow.offset = body.offset
	shadow.position = anchor
	shadow.scale = body.scale
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.modulate.a = 0.35
	shadow.z_index = -1
	shadow.visible = false
	add_child(shadow)
	add_child(body)
	bodies.append(body)
	shadows.append(shadow)
	placements.append({"skin": skin, "scale": scale_value, "anchor": [anchor.x, anchor.y], "crop": [anchor.x - 12 * scale_value, anchor.y - 21 * scale_value, 24 * scale_value, 24 * scale_value], "magnifier": magnifier})
	if scale_value == 1:
		body.animation_finished.connect(_on_finished.bind(skin))
		body.frame_changed.connect(_on_frame.bind(skin, body))

func _draw() -> void:
	for placement in placements:
		var at = Vector2(placement.anchor[0], placement.anchor[1])
		var s = placement.scale
		draw_line(Vector2(at.x - 13 * s, at.y + 2), Vector2(at.x + 13 * s, at.y + 2), Color("8caa99"), 1.0, false)
		draw_line(Vector2(at.x, at.y + 3), Vector2(at.x, at.y + 8), Color("d3d9b9"), 1.0, false)

func _on_finished(skin: int) -> void:
	completed[skin] = true
	finished_at[skin] = (Time.get_ticks_usec() - case_start) / 1000000.0

func _on_frame(skin: int, body: AnimatedSprite2D) -> void:
	if body.animation == active_case and not observed[skin].has(body.frame):
		observed[skin].append(body.frame)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _validate_loaded_resources() -> void:
	var layout = JSON.parse_string(FileAccess.get_file_as_string(ASSET_ROOT + "animation_layout.json"))
	DirAccess.make_dir_recursive_absolute(output.path_join("reference"))
	for skin in range(2):
		for suffix in ["_cube_sheet.png", "_sprite_frames.tres"]:
			DirAccess.copy_absolute(ProjectSettings.globalize_path(ASSET_ROOT + SKINS[skin] + suffix), output.path_join("reference").path_join(SKINS[skin] + suffix))
		var config = ConfigFile.new()
		_check(config.load(ASSET_ROOT + SKINS[skin] + "_cube_sheet.png.import") == OK, "Import metadata load")
		var tex = load(ASSET_ROOT + SKINS[skin] + "_cube_sheet.png") as Texture2D
		var imp = {"skin": SKINS[skin], "compress_mode": config.get_value("params", "compress/mode"), "mipmaps": config.get_value("params", "mipmaps/generate"), "actual_mipmaps": tex.get_image().has_mipmaps(), "texture_size": [tex.get_width(), tex.get_height()]}
		report.imports.append(imp)
		_check(imp.compress_mode == 0 and not imp.mipmaps and not imp.actual_mipmaps, "Lossless / mipmap import: " + SKINS[skin])
		_check(tex.get_size() == Vector2(144, 264), "Imported sheet size")
		for definition in layout.animations:
			var animation = StringName(definition.name)
			var sf = resources[skin]
			_check(sf.has_animation(animation), "Missing animation " + animation)
			_check(sf.get_frame_count(animation) == definition.cols.size(), "Frame count " + animation)
			_check(is_equal_approx(sf.get_animation_speed(animation), float(definition.fps)), "FPS " + animation)
			_check(sf.get_animation_loop(animation) == definition.loop, "Loop " + animation)
			for index in range(sf.get_frame_count(animation)):
				var atlas = sf.get_frame_texture(animation, index) as AtlasTexture
				_check(atlas != null and atlas.region == Rect2(definition.cols[index] * 24, definition.row * 24, 24, 24), "Atlas region " + animation)
				_check(atlas.filter_clip, "Atlas filter_clip " + animation)
				var expected_duration = definition.get("durations", [])[index] if definition.has("durations") else 1
				_check(is_equal_approx(sf.get_frame_duration(animation, index), float(expected_duration)), "Frame duration " + animation)
		for example in [SKINS[skin] + "_sprite_example.tscn"]:
			var node = (load(ASSET_ROOT + example) as PackedScene).instantiate()
			_check(node.get_node("Body").offset == Vector2(0, -9), "Example pivot")
			_check(node.get_node("Body").texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Example Nearest")
			node.free()

func _reset_resources() -> void:
	for i in range(bodies.size()):
		bodies[i].sprite_frames = resources[placements[i].skin]

func _play(animation: String) -> void:
	_reset_resources()
	active_case = animation
	completed = [false, false]
	finished_at = [0.0, 0.0]
	observed = [[0], [0]]
	case_start = Time.get_ticks_usec()
	for body in bodies:
		body.stop()
		body.play(animation)
	info.text = "Playing: " + animation + " | FPS " + str(resources[0].get_animation_speed(animation))

func _capture(filename: String, animation: String, shadow_visible: bool = false) -> Dictionary:
	var image = get_viewport().get_texture().get_image()
	var record = {"file": filename + ".png", "animation": animation, "frames": [bodies[0].frame, bodies[1].frame], "shadow": shadow_visible, "elapsed": (Time.get_ticks_usec() - case_start) / 1000000.0, "width": image.get_width(), "height": image.get_height()}
	_check(image.save_png(output.path_join(record.file)) == OK, "Framebuffer capture failed")
	captures.append(record)
	return record

func _run_suite() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	for animation in CASES:
		_play(animation)
		var sf = resources[0]
		var total = 0.0
		for f in range(sf.get_frame_count(animation)):
			total += sf.get_frame_duration(animation, f) / sf.get_animation_speed(animation)
		var seen_rendered: Array = []
		var last_frame = -1
		var elapsed = 0.0
		while elapsed < total + 1.5:
			await RenderingServer.frame_post_draw
			var frame = bodies[0].frame
			_check(frame == bodies[1].frame, "Paired frame desync " + animation)
			for body in bodies:
				_check(body.frame == frame, "Scale panel frame desync " + animation)
			if frame != last_frame:
				_capture(animation + "_f" + str(frame), animation)
				if not seen_rendered.has(frame):
					seen_rendered.append(frame)
				last_frame = frame
			elapsed = (Time.get_ticks_usec() - case_start) / 1000000.0
			if (sf.get_animation_loop(animation) and elapsed >= total) or (not sf.get_animation_loop(animation) and completed[0] and completed[1]):
				break
			await get_tree().process_frame
		_check(seen_rendered.size() == sf.get_frame_count(animation), "Some frames not rendered " + animation + ": " + str(seen_rendered))
		if not sf.get_animation_loop(animation):
			_check(completed[0] and completed[1], "animation_finished missing " + animation)
			_check(abs(finished_at[0] - finished_at[1]) < 0.02, "Skin duration mismatch " + animation)
		report.cases.append({"animation": animation, "expected_seconds": total, "observed_frames": observed.duplicate(true), "rendered_frames": seen_rendered, "finished_seconds": finished_at.duplicate(), "loop": sf.get_animation_loop(animation), "passed": seen_rendered.size() == sf.get_frame_count(animation)})
		if animation == "world_switch":
			var before = _capture("world_switch_handoff_before", animation)
			for i in range(bodies.size()):
				bodies[i].sprite_frames = resources[1 - placements[i].skin]
				bodies[i].play("idle")
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var after = _capture("world_switch_handoff_after", "target_idle")
			report.switch_handoffs.append({"directions": ["Mutsumi -> Mortis", "Mortis -> Mutsumi"], "before": before.file, "after": after.file})
		for body in bodies:
			body.stop()
	_play("idle")
	for shadow in shadows:
		shadow.visible = true
		shadow.play("shadow")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_capture("shadow_idle_a", "idle", true)
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	_capture("shadow_idle_b", "idle", true)
	report.shadow = {"animation_playing": shadows[0].is_playing(), "frame": shadows[0].frame, "position_fixed": true, "opacity": shadows[0].modulate.a}
	report.captures = captures
	report.failures = failures
	report.status = "ENGINE_RUN_PASS" if failures.is_empty() else "ENGINE_RUN_FAIL"
	var file = FileAccess.open(output.path_join("engine_runtime_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("SPRITE_RUNTIME_RESULT " + report.status + " | " + output)
	get_tree().quit(0 if failures.is_empty() else 2)

func _unhandled_key_input(event: InputEvent) -> void:
	if automatic or not event is InputEventKey or not event.pressed or event.echo:
		return
	var mapping = {KEY_1: "idle", KEY_2: "subtle_idle", KEY_3: "roll_left", KEY_4: "roll_right", KEY_5: "roll_forward", KEY_6: "roll_backward", KEY_7: "interaction", KEY_8: "puzzle_complete", KEY_SPACE: "world_switch"}
	if mapping.has(event.keycode):
		_play(mapping[event.keycode])
	if event.keycode == KEY_S:
		for shadow in shadows:
			shadow.visible = not shadow.visible
			shadow.play("shadow")
