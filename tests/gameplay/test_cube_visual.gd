extends SceneTree
var game
var checks:=0
var failures: Array[String]=[]
var traces: Array=[]
var evidence:="res://tests/gameplay/evidence/cube_visual_final_01"
const Orientation=preload("res://prototype/perspective/cube_orientation.gd")
func _initialize() -> void:
	if not ResourceLoader.exists("res://game/player/cube_visual_presenter.gd"):
		printerr("FAIL: orientation-aware P01 presenter missing"); quit(1); return
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("FAIL: ",label)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence=arg.trim_prefix("--evidence-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	game=load("res://tests/gameplay/cube_orientation_visual_test.tscn").instantiate()
	root.add_child(game); await delay(0.3)
	var initial: String=game.mover.orientation.key()
	var directions: Array=["SOUTH","TOP","NORTH","BOTTOM","SOUTH"]
	var visibility: Array=[true,true,false,false,true]
	for w in 2:
		await tap(KEY_R)
		if w==1: await tap(KEY_SPACE)
		for step in 5:
			check(game.cube.face_world_direction()==directions[step],"NORTH face direction world%s step%s"%[w,step])
			check(game.cube.face_is_visible()==visibility[step],"NORTH face visibility world%s step%s"%[w,step])
			check(game.cube.world_basis().is_equal_approx(game.mover.orientation.as_basis()),"settled visual basis equals logical orientation")
			await shot("world_%s_north_%s"%[w,step])
			check((marker_pixels()>0)==visibility[step],"actual rendered X agrees with face visibility")
			if step<4: await tap(KEY_W)
		check(game.mover.orientation.key()==initial,"North x4 restores initial pose")
	await tap(KEY_R)
	for i in 4: await tap(KEY_D)
	check(game.mover.orientation.key()==initial,"East x4 restores pose")
	await tap(KEY_W); await tap(KEY_S)
	check(game.mover.orientation.key()==initial,"North South cancel")
	await tap(KEY_D); await tap(KEY_A)
	check(game.mover.orientation.key()==initial,"East West cancel")
	await tap(KEY_R); await tap(KEY_W)
	var held_pose: String=game.mover.orientation.key()
	await delay(5.1)
	check(game.mover.orientation.key()==held_pose and game.cube.face_world_direction()=="TOP" and game.cube.world_basis().is_equal_approx(game.mover.orientation.as_basis()),"CASE B: no reset after five seconds")
	await shot("case_b_after_5_seconds")
	await tap(KEY_Q)
	check(game.mover.orientation.key()==held_pose and game.view.current==3 and game.cube.face_world_direction()=="TOP","CASE C: rotate camera only")
	await shot("case_c_camera_only")
	await tap(KEY_SPACE)
	check(game.mover.world==1 and game.mover.orientation.key()==held_pose and game.cube.face_world_direction()=="TOP","CASE D: World Shift preserves top face and orientation")
	await shot("case_d_shift_top")
	# One key press drives consecutive rolls, with endpoint observed before commit.
	await tap(KEY_R)
	await key(KEY_W,true)
	while game.mover.fraction<0.8: await process_frame
	var target: Basis=game.cube.target_basis()
	var near_end: Basis=game.cube.world_basis()
	check(not near_end.is_equal_approx(Basis.IDENTITY),"roll actually interpolates from initial pose")
	while game.mover.moves<1: await process_frame
	check(game.mover.moving and game.mover.orientation.as_basis().is_equal_approx(target),"CASE E: second roll starts at first target orientation")
	await delay(0.7); await key(KEY_W,false); await delay(0.4)
	check(game.mover.moves>=3 and not game.mover.moving,"single held input makes consecutive complete rolls")
	await shot("case_e_held_rolls")
	# Enumerate 24 legal physical orientations. Test all four cameras and skins.
	var queue: Array=[Orientation.new()]
	var poses: Dictionary={}
	while not queue.is_empty():
		var pose=queue.pop_front()
		if poses.has(pose.key()): continue
		poses[pose.key()]=pose
		for d in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next=pose.copy(); next.roll(d); queue.append(next)
	check(poses.size()==24,"exactly 24 proper physical poses")
	var visible_world_faces: Array=[["TOP","EAST","SOUTH"],["TOP","WEST","SOUTH"],["TOP","WEST","NORTH"],["TOP","EAST","NORTH"]]
	await tap(KEY_R)
	for pose in poses.values():
		game.mover.orientation=pose
		for v in 4:
			game.view.current=v
			for w in 2:
				game.mover.world=w
				game.cube.refresh(); await RenderingServer.frame_post_draw
				var expected: bool=game.cube.face_world_direction() in visible_world_faces[v]
				check(game.cube.world_basis().is_equal_approx(pose.as_basis()),"all 24/4/2: view and skin preserve physical basis")
				check(game.cube.face_is_visible()==expected and game.cube.face_visible==expected,"all 24/4/2: correct visible physical face")
				check((marker_pixels()>0)==expected,"all 24/4/2: GPU has X only when physical face visible")
	await tap(KEY_R)
	var pose_key: String=game.mover.orientation.key()
	await tap(KEY_E,2)
	check(game.mover.orientation.key()==pose_key and not game.cube.face_is_visible(),"stationary face hides when camera rotates behind")
	await shot("camera_south_face_hidden")
	await drag(Vector2(700,550),Vector2(500,550))
	check(game.view.current==1 and game.mover.orientation.key()==pose_key and game.cube.face_is_visible(),"mouse changes visibility without rolling face")
	await tap(KEY_F3); check(not game.debug.visible,"F3 hides orientation diagnostics")
	await tap(KEY_F3); check(game.debug.visible,"F3 restores orientation diagnostics")
	print("CUBE VISUAL: ",checks," checks; failures=",failures)
	var f:=FileAccess.open(evidence.path_join("runtime_report.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"traces":traces},"\t")); f.close()
	game.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
func marker_pixels() -> int:
	var image:=root.get_texture().get_image()
	var count:=0
	# Only the enlarged cube area; text never participates in this pixel assertion.
	var center: Vector2=game.cube.position
	for y in range(int(center.y)-250,int(center.y)+60):
		for x in range(int(center.x)-250,int(center.x)+250):
			var c:=image.get_pixel(x,y)
			if absf(c.r-237.0/255)<0.005 and absf(c.g-185.0/255)<0.005 and absf(c.b-79.0/255)<0.005: count+=1
	return count
func delay(seconds: float) -> void: await create_timer(seconds).timeout
func key(code: int,pressed: bool) -> void:
	var e:=InputEventKey.new(); e.physical_keycode=code; e.keycode=code; e.pressed=pressed
	Input.parse_input_event(e); await process_frame
func tap(code: int,count: int=1) -> void:
	for i in count:
		await key(code,true); await key(code,false); await delay(0.46)
func drag(from: Vector2,to: Vector2) -> void:
	var e:=InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT; e.position=from; e.pressed=true
	Input.parse_input_event(e); await process_frame
	var m:=InputEventMouseMotion.new(); m.position=to; Input.parse_input_event(m); await process_frame
	e=InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT; e.position=to; e.pressed=false
	Input.parse_input_event(e); await delay(0.5)
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(label+".png"))
	traces.append({"name":label,"logical":game.mover.orientation.key(),"face":game.cube.face_world_direction(),"visible":game.cube.face_is_visible(),"world":game.mover.world,"view":game.view.current,"roll":game.mover.phase})
