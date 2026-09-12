extends Node2D
const ROOT = "res://production/mechanisms/"
const KINDS = ["pressure_plate","door","moving_platform","rotator","exit"]
const BG = Color("24313a")
var output = ""
var automatic = false
var manifest: Dictionary
var definitions: Array = [{},{}]
var stage: Node2D
var mechanisms: Array = []
var actors: Array = []
var report: Dictionary = {"failures":[],"captures":[],"imports":[],"events":[],"interactions":[],"motion":[],"animation_observed":{}}

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--auto": automatic = true
		if arg.begins_with("--evidence-dir="): output = arg.trim_prefix("--evidence-dir=")
	if output.is_empty(): output = ProjectSettings.globalize_path("res://tests/visual/mechanism_evidence/manual")
	DirAccess.make_dir_recursive_absolute(output)
	get_window().title = "Puzzle Mechanism Runtime Validation"
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size = Vector2i.ZERO
	get_window().unresizable = true
	get_window().size = Vector2i(1280,960)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bg = ColorRect.new()
	bg.color = BG
	bg.size = Vector2(1280,960)
	bg.z_index = -100
	add_child(bg)
	manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"mechanism_manifest.json"))
	for m in manifest.mechanisms: definitions[0 if m.world == "surface" else 1][m.kind] = m
	report.engine = Engine.get_version_info()
	report.display_server = DisplayServer.get_name()
	report.renderer = RenderingServer.get_current_rendering_method()
	report.driver = RenderingServer.get_current_rendering_driver_name()
	report.gpu = RenderingServer.get_video_adapter_name()
	report.window = [get_window().size.x,get_window().size.y]
	report.filter = texture_filter
	validate_imports()
	if automatic: run_suite.call_deferred()
	else: demo()

func check(ok: bool,text: String) -> void:
	if not ok: report.failures.append(text)

func validate_imports() -> void:
	for m in manifest.mechanisms:
		var texture = load(ROOT+m.texture) as Texture2D
		var config = ConfigFile.new()
		config.load(ROOT+m.texture+".import")
		var values = {"path":m.texture,"compression":config.get_value("params","compress/mode"),"mipmaps":config.get_value("params","mipmaps/generate"),"loaded_mipmaps":texture.get_image().has_mipmaps()}
		check(values.compression == 0 and not values.mipmaps and not values.loaded_mipmaps,"import "+m.texture)
		report.imports.append(values)
		var pair = definitions[1 if m.world == "surface" else 0][m.kind]
		for key in ["logical_id","frame_size","pivot","footprint","collision_type","states","interaction_type"]: check(m[key] == pair[key],"parity "+m.kind+" "+key)
		var node = load(ROOT+m.scene).instantiate()
		var frames = node.get_node("Visual").sprite_frames
		for state in m.states:
			var s = m.states[state]
			check(frames.get_frame_count(state) == s.frames.size(),"frame count")
			check(frames.get_animation_speed(state) == s.fps and frames.get_animation_loop(state) == s.loop,"animation config")
			for f in range(s.frames.size()): check(frames.get_frame_texture(state,f).region == Rect2(s.frames[f]*64,0,64,96),"frame region")
		node.free()

func reset(title: String) -> void:
	if is_instance_valid(stage):
		remove_child(stage)
		stage.queue_free()
	stage = Node2D.new()
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(stage)
	mechanisms.clear()
	actors.clear()
	label(title,Vector2(30,20),25)

func label(text: String,at: Vector2,size: int = 18) -> void:
	var l = Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size",size)
	stage.add_child(l)

func group(at: Vector2,factor: int) -> Node2D:
	var g = Node2D.new()
	g.position = at
	g.scale = Vector2.ONE * factor
	g.y_sort_enabled = true
	stage.add_child(g)
	return g

func mechanism(g: Node2D,w: int,kind: String) -> Node2D:
	var m = load(ROOT+definitions[w][kind].scene).instantiate()
	g.add_child(m)
	m.state_changed.connect(func(value): report.events.append({"world":w,"kind":kind,"state":value}))
	mechanisms.append(m)
	return m

func actor(g: Node2D,w: int,at: Vector2,depth: int = 1) -> CharacterBody2D:
	var body = CharacterBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 1
	body.position = at
	body.z_index = depth
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 1
	shape.shape = circle
	body.add_child(shape)
	var visual = AnimatedSprite2D.new()
	visual.name = "CharacterVisual"
	visual.sprite_frames = load("res://production/sprites/"+("mutsumi" if w == 0 else "mortis")+"_sprite_frames.tres")
	visual.animation = "idle"
	visual.offset = Vector2(0,-9)
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(visual)
	g.add_child(body)
	actors.append(body)
	return body

func floor_tile(g: Node2D,w: int) -> void:
	var l = TileMapLayer.new()
	l.tile_set = load("res://production/tilesets/"+("surface" if w == 0 else "inner")+"_tileset.tres")
	l.position = -l.map_to_local(Vector2i.ZERO)
	l.z_index = -2
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l.set_cell(Vector2i.ZERO,0,Vector2i.ZERO)
	g.add_child(l)

func demo() -> void:
	reset("PUZZLE MECHANISMS / PAIRED ASSET BENCH / 3x")
	for w in range(2):
		label("SURFACE" if w == 0 else "INNER",Vector2(250+w*640,80),23)
		for k in range(5):
			var pos = Vector2(130+(k%3)*180+w*640,280+(k/3)*330)
			var g = group(pos,3)
			floor_tile(g,w)
			var m = mechanism(g,w,KINDS[k])
			label(KINDS[k],pos+Vector2(-80,70),17)
			if k in [0,2]: actor(g,w,Vector2.ZERO)
			if k == 4: m.set_ready(true)
	label("1 plate | 2 gate | 3 platform | 4 rotator | 5 goal | D all mechanisms",Vector2(30,900),18)

func pair(kind: String,with_actor: bool = false,actor_at: Vector2 = Vector2(40,20)) -> void:
	reset("INTERACTION / "+kind+" / 4x")
	for w in range(2):
		var g = group(Vector2(320+w*640,390),4)
		mechanism(g,w,kind)
		if with_actor: actor(g,w,actor_at)

func physics_settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame

func wait_trigger(expected_state: String = "",expected_count: int = -1) -> void:
	for attempt in range(30):
		await get_tree().physics_frame
		await get_tree().process_frame
		var matched = true
		for m in mechanisms:
			if not expected_state.is_empty() and m.state != expected_state: matched = false
			if expected_count >= 0 and m.get_node("Trigger").get_overlapping_bodies().size() != expected_count: matched = false
		if matched:
			report.interactions.append({"trigger_wait_frames":attempt+1,"expected_state":expected_state,"expected_overlap":expected_count})
			return
	check(false,"trigger timeout "+expected_state+" overlap="+str(expected_count))

func hit(point: Vector2,mask: int) -> bool:
	var q = PhysicsPointQueryParameters2D.new()
	q.position = point
	q.collision_mask = mask
	return not get_world_2d().direct_space_state.intersect_point(q).is_empty()

func capture(file: String,kind: String,placements: Array = []) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image = get_viewport().get_texture().get_image()
	check(image.save_png(output+"/"+file+".png") == OK,"capture")
	report.captures.append({"file":file+".png","kind":kind,"placements":placements})

func gallery(kind: String,factor: int,start: int) -> Array:
	reset("PIXEL STATES / "+kind+" / "+str(factor)+"x")
	var places = []
	for w in range(2):
		for slot in range(4):
			var index = start+slot
			if index >= definitions[w][kind].frame_count: continue
			var pos = Vector2(160+320*slot,270+440*w)
			var g = group(pos,factor)
			var sprite = Sprite2D.new()
			sprite.texture = load(ROOT+definitions[w][kind].texture)
			sprite.region_enabled = true
			sprite.region_rect = Rect2(index*64,0,64,96)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			g.add_child(sprite)
			label(("Surface" if w == 0 else "Inner")+" / frame "+str(index),pos+Vector2(-145,-215),14)
			places.append({"world":w,"mechanism":kind,"source_frame":index,"scale":factor,"anchor":[pos.x,pos.y]})
	return places

func animation_suite() -> void:
	for kind in KINDS:
		pair(kind)
		for animation in definitions[0][kind].states:
			var settings = definitions[0][kind].states[animation]
			for m in mechanisms: m.set_state(animation)
			var observed = [[],[]]
			var elapsed = 0.0
			var seconds = settings.frames.size()/float(settings.fps)+0.12
			while elapsed < seconds:
				await RenderingServer.frame_post_draw
				for w in range(2):
					var v = mechanisms[w].visual
					if str(v.animation) == animation and v.frame not in observed[w]: observed[w].append(v.frame)
				elapsed += get_process_delta_time()
			for w in range(2):
				report.animation_observed[kind+"/"+animation+"/"+str(w)] = observed[w]
				check(observed[w].size() == settings.frames.size(),"animation missing frame "+kind+" "+animation+" "+str(w))
			await capture("animation_"+kind+"_"+animation,"animation")

func pressure_test() -> void:
	pair("pressure_plate",true)
	await physics_settle()
	for m in mechanisms: check(m.state == "idle","plate idle")
	for a in actors: a.position = Vector2.ZERO
	await wait_trigger("pressed",1)
	for m in mechanisms: check(m.state == "pressed" and m.occupants.size() == 1,"plate area entry")
	await capture("plate_pressed_actor","interaction")
	for m in mechanisms: m.set_active(true)
	await capture("plate_active_actor","interaction")
	for a in actors: a.position = Vector2(40,20)
	await wait_trigger("active",0)
	for m in mechanisms:
		check(m.state == "active" and m.occupants.is_empty(),"plate active latch and area exit")
		m.set_active(false)
		check(m.state == "idle","plate reset")
	report.interactions.append({"kind":"pressure_plate","area_enter_exit":true,"activated_reset":true})

func door_test() -> void:
	pair("door",true,Vector2(12,-6))
	await physics_settle()
	for w in range(2):
		check(hit(mechanisms[w].global_position,1),"door closed collision")
		check(actors[w].test_move(actors[w].global_transform,Vector2(-96,48)),"door closed passage")
	for m in mechanisms: m.set_open(true)
	await get_tree().create_timer(0.45).timeout
	await physics_settle()
	for w in range(2):
		check(mechanisms[w].state == "open" and not hit(mechanisms[w].global_position,1),"door open collision")
		check(not actors[w].test_move(actors[w].global_transform,Vector2(-96,48)),"door open passage")
	await capture("door_open_passage","interaction")
	for m in mechanisms: m.set_open(false)
	await get_tree().create_timer(0.45).timeout
	await physics_settle()
	for m in mechanisms: check(m.state == "closed" and hit(m.global_position,1),"door reclose")
	report.interactions.append({"kind":"door","closed_blocked":true,"open_passable":true,"reclosed":true})

func moving_test() -> void:
	for axis in [Vector2(32,16),Vector2(-32,16),Vector2(32,0)]:
		pair("moving_platform",true,Vector2.ZERO)
		for w in range(2): mechanisms[w].translated.connect(func(delta): actors[w].position += delta)
		await physics_settle()
		for m in mechanisms:
			check(not m.move_to(Vector2(1,1)),"reject off-grid destination")
			check(m.move_to(axis,0.6),"start move")
		var samples = 0
		var halfway = false
		while mechanisms[0].state == "moving":
			await get_tree().process_frame
			for w in range(2):
				var m = mechanisms[w]
				check(m.position == m.position.round(),"fractional platform position")
				check(actors[w].position == m.position,"rider drift")
				check(m.get_node("Support").global_position == m.global_position,"support transform drift")
				check(hit(m.global_position,2),"support collision lost while moving")
				samples += 1
			if not halfway and mechanisms[0].elapsed > 0.3:
				halfway = true
				await capture("moving_"+str(axis.x)+"_"+str(axis.y)+"_mid","motion")
		await physics_settle()
		for m in mechanisms: check(m.position == axis and m.state == "arrived","exact docking")
		await capture("moving_"+str(axis.x)+"_"+str(axis.y)+"_arrived","motion")
		report.motion.append({"target":[axis.x,axis.y],"samples":samples,"integer_positions":true,"rider_offset":[0,0],"docked":true})
		for m in mechanisms: m.move_to(Vector2.ZERO,0.2)
		await get_tree().create_timer(0.3).timeout
		for w in range(2): check(mechanisms[w].position == Vector2.ZERO and actors[w].position == Vector2.ZERO,"return dock")

func rotator_test() -> void:
	pair("rotator")
	await physics_settle()
	for m in mechanisms:
		check(hit(m.global_position+Vector2(24,12),2) and not hit(m.global_position+Vector2(-24,12),2),"rotator A support")
		check(m.rotate_to(1),"rotator start")
		check(not m.rotate_to(0),"rotator input locked")
	await physics_settle()
	for m in mechanisms: check(not hit(m.global_position,2),"transient rotator support disabled")
	await get_tree().create_timer(0.4).timeout
	await physics_settle()
	for m in mechanisms:
		check(m.orientation == 1 and m.state == "orientation_b","rotator B commit")
		check(not hit(m.global_position+Vector2(24,12),2) and hit(m.global_position+Vector2(-24,12),2),"rotator B support")
		check(m.rotation == 0 and m.visual.rotation == 0,"no Sprite/camera rotation")
	await capture("rotator_B","interaction")
	for m in mechanisms: m.rotate_to(0)
	await get_tree().create_timer(0.45).timeout
	for m in mechanisms: check(m.orientation == 0 and m.state == "orientation_a","rotator A return")
	report.interactions.append({"kind":"rotator","a_b_a":true,"transient_support_disabled":true,"sprite_rotation":0})

func exit_test() -> void:
	pair("exit",true,Vector2.ZERO)
	await wait_trigger("locked",1)
	for m in mechanisms: check(m.state == "locked" and not m.complete_goal(),"locked exit rejection")
	for a in actors: a.position = Vector2(40,20)
	await wait_trigger("locked",0)
	for m in mechanisms: m.set_ready(true)
	await capture("exit_ready","interaction")
	for a in actors: a.position = Vector2.ZERO
	await wait_trigger("active",1)
	for m in mechanisms: check(m.state == "active","ready exit trigger")
	await capture("exit_active_actor","interaction")
	for m in mechanisms: check(m.complete_goal(),"complete eligible goal")
	await get_tree().create_timer(0.4).timeout
	for m in mechanisms: check(m.state == "completed","goal completion finished")
	await capture("exit_completed","interaction")
	report.interactions.append({"kind":"exit","locked_rejected":true,"ready_triggered":true,"complete_finished":true})

func depth_test() -> void:
	for pose in ["plate_top","moving_top","door_front","door_behind"]:
		var kind = "pressure_plate" if pose == "plate_top" else ("moving_platform" if pose == "moving_top" else "door")
		for mode in ["mechanism_only","actor_only","combined"]:
			pair(kind,true,Vector2(0,-10) if pose.ends_with("behind") else (Vector2(0,10) if pose.ends_with("front") else Vector2.ZERO))
			for w in range(2):
				actors[w].z_index = 0 if kind == "door" else 1
				mechanisms[w].visible = mode != "actor_only"
				actors[w].visible = mode != "mechanism_only"
			await physics_settle()
			await capture("depth_"+pose+"_"+mode,"depth")

func run_suite() -> void:
	demo()
	await physics_settle()
	await capture("paired_mechanisms","demo")
	for factor in range(1,5):
		for kind in KINDS:
			for start in range(0,int(definitions[0][kind].frame_count),4):
				var p = gallery(kind,factor,start)
				await capture("gallery_"+kind+"_"+str(factor)+"x_"+str(start),"gallery",p)
	await animation_suite()
	await pressure_test()
	await door_test()
	await moving_test()
	await rotator_test()
	await exit_test()
	await depth_test()
	demo()
	await physics_settle()
	await capture("paired_mechanisms_final","demo")
	report.status = "ENGINE_CHECKS_PASS" if report.failures.is_empty() else "ENGINE_CHECKS_FAIL"
	var file = FileAccess.open(output+"/engine_runtime_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print(report.status," failures=",report.failures)
	get_tree().quit(0 if report.failures.is_empty() else 2)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or automatic: return
	if event.keycode == KEY_D: demo()
	if event.keycode == KEY_1: pair("pressure_plate",true,Vector2.ZERO)
	if event.keycode == KEY_2:
		pair("door")
		for m in mechanisms: m.set_open(true)
	if event.keycode == KEY_3:
		pair("moving_platform",true,Vector2.ZERO)
		for w in range(2):
			mechanisms[w].translated.connect(func(delta): actors[w].position += delta)
			mechanisms[w].move_to(Vector2(32,16))
	if event.keycode == KEY_4:
		pair("rotator")
		for m in mechanisms: m.rotate_to(1)
	if event.keycode == KEY_5:
		pair("exit",true,Vector2.ZERO)
		for m in mechanisms: m.set_ready(true)
