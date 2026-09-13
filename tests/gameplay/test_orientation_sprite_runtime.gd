extends SceneTree
var game
var checks:=0
var failures: Array[String]=[]
var traces: Array=[]
var evidence:="res://tests/gameplay/evidence/sprite_rework/runtime_01"
func _initialize() -> void:
	if not ResourceLoader.exists("res://game/player/orientation_sprite_presenter.gd"):
		printerr("FAIL: formal Sprite Presenter missing"); quit(1); return
	call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence=arg.trim_prefix("--evidence-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	game=load("res://tests/gameplay/orientation_sprite_visual_test.tscn").instantiate()
	root.add_child(game); await delay(0.5)
	var original: String=game.mover.orientation.key()
	for w in 2:
		await tap(KEY_R)
		if w==1: await tap(KEY_SPACE)
		for step in 5:
			check(game.cube.face_world_direction()==["SOUTH","TOP","NORTH","BOTTOM","SOUTH"][step],"A physical cycle")
			parity(); await pixels(); await shot("A_%s_%s"%[w,step])
			if step<4: await tap(KEY_W)
		check(game.mover.orientation.key()==original,"A full cycle returns")
	await tap(KEY_R); await tap(KEY_W)
	var top: String=game.mover.orientation.key()
	await delay(10.1); parity(); await pixels(); await shot("B_top_after_10_seconds")
	check(game.mover.orientation.key()==top and game.cube.face_world_direction()=="TOP","B no idle reset")
	for i in 4:
		await tap(KEY_Q); parity(); await pixels(); await shot("C_camera_%s"%i)
		check(game.mover.orientation.key()==top,"C camera preserves logical pose")
	await tap(KEY_SPACE); parity(); await pixels(); await shot("D_mortis_top")
	check(game.mover.world==1 and game.mover.orientation.key()==top and game.cube.face_world_direction()=="TOP","D Shift top")
	await tap(KEY_R); await key(KEY_W,true)
	var last_moves:=0
	var expected: Basis=game.cube.target_basis()
	while game.mover.moves<5:
		await process_frame
		if game.mover.moves!=last_moves:
			check(game.mover.orientation.as_basis().is_equal_approx(expected),"E each held roll starts at previous target")
			last_moves=game.mover.moves; expected=game.cube.target_basis()
			parity()
	await key(KEY_W,false); await delay(0.5); parity(); await pixels(); await shot("E_held_five_plus")
	check(game.mover.moves>=5 and not game.mover.moving,"E >=5 rolls with one persistent press")
	await tap(KEY_R)
	for code in [KEY_W,KEY_D,KEY_S,KEY_A]: await tap(code); parity(); await pixels()
	await shot("F_mixed_sequence")
	# Validate all 24 physical poses, four committed views, both imported skins.
	var Orientation=load("res://prototype/perspective/cube_orientation.gd")
	var queue: Array=[Orientation.new()]; var poses: Dictionary={}
	while not queue.is_empty():
		var o=queue.pop_front()
		if poses.has(o.key()): continue
		poses[o.key()]=o
		for d in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var n=o.copy(); n.roll(d); queue.append(n)
	check(poses.size()==24,"24 existing logical poses")
	await tap(KEY_R)
	game.set_process(false)
	for o in poses.values():
		game.mover.orientation=o
		for v in 4:
			game.view.current=v
			for w in 2:
				game.mover.world=w; game.cube.refresh(); parity(); await pixels()
	# Exact endpoints for every imported roll. Intermediate frame selection is sampled,
	# and rendered pixel checks prevent a passing matrix hiding a default sprite.
	await tap(KEY_R)
	for o in poses.values():
		game.mover.orientation=o
		for d in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			game.mover.phase="roll"; game.mover.direction=d
			for f in [0.0,0.25,0.5,0.75,1.0]:
				game.mover.elapsed=f*game.mover.ROLL_SECONDS; game.cube.refresh()
				var want: Basis=o.as_basis()
				if f==1:
					var n=o.copy(); n.roll(d); want=n.as_basis()
				if f in [0.0,1.0]: check(game.cube.world_basis().is_equal_approx(want),"roll sampling exact endpoints")
				# Freeze fixture tick while reading controlled transition samples.
				await pixels()
		game.mover.phase="idle"
	game.set_process(true)
	await tap(KEY_R)
	await drag(Vector2(850,590),Vector2(600,590)); parity(); await pixels()
	check(game.view.current==3,"mouse camera mapping")
	await tap(KEY_F3); check(not game.debug.visible,"F3 off")
	await tap(KEY_F3); check(game.debug.visible,"F3 on")
	print("FORMAL SPRITE RUNTIME: ",checks," checks; failures=",failures)
	FileAccess.open(evidence.path_join("runtime_report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"traces":traces,"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name()},"\t"))
	game.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
func parity() -> void:
	game.cube.refresh()
	check(game.cube.face_world_direction()==game.reference.face_world_direction(),"formal face world direction equals debug X")
	check(game.cube.FACE_ID==game.reference.FACE_ID,"same fixed physical face identity")
	if not game.mover.moving and not game.view.busy:
		check(game.cube.world_basis().is_equal_approx(game.mover.orientation.as_basis()),"settled visual equals logical")
		check(game.cube.face_is_visible()==game.reference.face_is_visible(),"stable visibility equals X")
func pixels() -> void:
	game.cube.refresh(); await RenderingServer.frame_post_draw
	var actual:=root.get_texture().get_image()
	var sprite=game.cube
	var expected: Image=sprite.ATLAS[game.mover.world].get_image().get_region(sprite.frame_region())
	var origin: Vector2i=Vector2i(sprite.position)-Vector2i(12,21)*8
	var errors:=0
	for y in 24:
		for x in 24:
			var color:=expected.get_pixel(x,y)
			var want:=color if color.a>0.5 else Color("172327")
			for dy in 8:
				for dx in 8:
					var got:=actual.get_pixelv(origin+Vector2i(x,y)*8+Vector2i(dx,dy))
					if absf(got.r-want.r)>0.006 or absf(got.g-want.g)>0.006 or absf(got.b-want.b)>0.006: errors+=1
	check(errors==0,"GPU nearest RGBA matches selected formal atlas (%s wrong pixels)"%errors)
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(label+".png"))
	traces.append({"name":label,"orientation":game.mover.orientation.key(),"face":game.cube.face_world_direction(),"world":game.mover.world,"view":game.view.current,"frame":game.cube.frame_id,"moves":game.mover.moves})
func delay(seconds: float) -> void: await create_timer(seconds).timeout
func key(code: int,pressed: bool) -> void:
	var e:=InputEventKey.new(); e.keycode=code; e.physical_keycode=code; e.pressed=pressed
	Input.parse_input_event(e); await process_frame
func tap(code: int) -> void:
	await key(code,true); await key(code,false); await delay(0.47)
func drag(from: Vector2,to: Vector2) -> void:
	var e:=InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT; e.position=from; e.pressed=true
	Input.parse_input_event(e); await process_frame
	var m:=InputEventMouseMotion.new(); m.position=to; Input.parse_input_event(m); await process_frame
	e=InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT; e.position=to; e.pressed=false
	Input.parse_input_event(e); await delay(0.5)
