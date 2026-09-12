extends SceneTree
var game
var checks:=0
var failures: Array[String]=[]
var evidence:="res://tests/gameplay/evidence/runtime_01"
var checkpoints: Array=[]
func _initialize() -> void:
	if not ResourceLoader.exists("res://tests/gameplay/perspective_connection_tech_test.tscn"):
		printerr("FAIL: perspective runtime fixture is missing")
		quit(1)
		return
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("FAIL: ",label)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence=arg.trim_prefix("--evidence-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	game=load("res://tests/gameplay/perspective_connection_tech_test.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var pose: String=game.mover.orientation.key()
	check(game.mover.cell==Vector2i(0,4),"initial grid position")
	await shot("01_view_a_disconnected")
	check(game.cube.face_visible,"initial physical face visible")
	await key(KEY_W,true)
	await delay(0.77)
	check(game.mover.moves>=2 and game.mover.moving,"held W continues without repeat events")
	await key(KEY_W,false)
	await delay(0.5)
	check(game.mover.cell==Vector2i(0,1) and not game.mover.moving,"release finishes current cell then stops")
	var stopped: Vector2i=game.mover.cell
	await delay(0.4)
	check(game.mover.cell==stopped,"released key does not queue more moves")
	await tap(KEY_W)
	check(game.mover.orientation.key()==pose and game.mover.cell==Vector2i(0,0),"four north rolls restore original orientation")
	await shot("02_north_four")
	await tap(KEY_S)
	check(game.mover.orientation.face_direction()!=Vector3i(0,0,1),"single physical face changes direction")
	await shot("03_face_rolled")
	check(not game.cube.face_visible,"bottom physical face is hidden, not camera-facing")
	var cell: Vector2i=game.mover.cell
	pose=game.mover.orientation.key()
	await tap(KEY_SPACE)
	check(game.mover.world==1 and game.mover.cell==cell and game.mover.orientation.key()==pose,"Shift preserves position and orientation")
	await shot("04_inner_same_pose")
	await tap(KEY_SPACE)
	var revision: int=game.graph.revision
	await key(KEY_E,true)
	await key(KEY_E,false)
	await delay(0.1)
	check(game.view.busy and game.view.current==0,"snap in progress keeps old view")
	await key(KEY_D,true)
	await key(KEY_D,false)
	await key(KEY_SPACE,true)
	await key(KEY_SPACE,false)
	await key(KEY_Q,true)
	await key(KEY_Q,false)
	check(game.mover.cell==cell and game.mover.world==0 and game.mover.orientation.key()==pose and game.graph.revision==revision,"rotation locks move Shift repeated rotate and topology update")
	await delay(0.45)
	check(game.view.current==1 and not game.view.busy and game.graph.link.active,"View B snap activates aligned link")
	check(game.mover.cell==cell and game.mover.orientation.key()==pose,"view commit never changes cube state")
	await shot("05_view_b_aligned")
	var before: Vector2=game.view.project(Vector2(cell),0,0,1)
	await tap(KEY_W)
	var after: Vector2=game.view.project(Vector2(game.mover.cell),0,0,1)
	check(game.mover.cell==cell+Vector2i.RIGHT and after.y<before.y,"W is screen-up after view change")
	await key(KEY_R,true)
	await key(KEY_R,false)
	await tap(KEY_D,4)
	await tap(KEY_W,2)
	check(game.mover.cell==Vector2i(4,2),"arrive at authored Anchor A")
	await tap(KEY_D)
	check(game.mover.cell==Vector2i(4,2),"View A traversal blocked")
	await tap(KEY_E)
	# The fixture now permits both worlds; test the restrictive policy explicitly.
	game.graph.link.allowed_world_states=[0]
	await tap(KEY_SPACE)
	await tap(KEY_W)
	check(game.mover.cell==Vector2i(4,2) and not game.graph.link.active,"Inner View B traversal blocked")
	game.graph.link.allowed_world_states=[0,1]
	await tap(KEY_SPACE)
	pose=game.mover.orientation.key()
	await key(KEY_W,true)
	await key(KEY_W,false)
	await delay(0.15)
	check(game.mover.moving and game.mover.cell==Vector2i(4,2),"link crossing delays logical commit")
	check(game.mover.crossing,"link traversal recognized as edge")
	await shot("06_link_mid_roll")
	await key(KEY_E,true)
	await key(KEY_E,false)
	await mouse_button(true,Vector2(500,400))
	await mouse_motion(Vector2(700,400))
	await mouse_button(false,Vector2(700,400))
	check(not game.view.busy and game.view.current==1,"crossing locks keyboard and drag rotation")
	await delay(0.4)
	check(game.mover.cell==Vector2i(10,2) and game.mover.orientation.key()!=pose,"natural link roll commits B and orientation")
	check(game.cube.position==game.view.project(Vector2(10,2),0,1,1),"crossing lands at exact projected B center")
	await shot("07_arrived_b")
	await tap(KEY_Q)
	check(not game.graph.link.active and game.graph.nodes.has(game.mover.cell),"disconnect leaves B standable")
	await tap(KEY_A)
	check(game.mover.cell==Vector2i(10,2),"cannot return through disabled edge")
	await shot("08_b_after_disconnect")
	# Actual Godot mouse events, no direct controller calls.
	await drag(Vector2(500,400),Vector2(530,400))
	check(game.view.current==0 and not game.view.busy,"short drag rebounds")
	await drag(Vector2(500,400),Vector2(505,550))
	check(game.view.current==0,"vertical drag ignored")
	await drag(Vector2(650,400),Vector2(500,400))
	check(game.view.current==3 and not game.graph.link.active,"left drag NORTH to WEST uses legal snap")
	await drag(Vector2(500,400),Vector2(650,400))
	check(game.view.current==0 and not game.graph.link.active,"right drag uses same controller")
	await tap(KEY_E)
	await tap(KEY_S)
	check(game.mover.cell==Vector2i(4,2),"reverse link traversal")
	await tap(KEY_F3)
	check(not game.overlay.visible,"Debug overlay can be disabled")
	await shot("09_overlay_off")
	await tap(KEY_F3)
	await key(KEY_W,true)
	await delay(0.1)
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await delay(0.6)
	check(not game.mover.moving and game.mover.held.is_empty(),"focus loss clears held input and finishes roll")
	await key(KEY_R,true)
	await key(KEY_R,false)
	await tap(KEY_E)
	await key(KEY_W,true)
	await delay(0.1)
	await key(KEY_R,true)
	await key(KEY_R,false)
	await delay(0.6)
	check(game.mover.cell==Vector2i(0,4) and game.mover.orientation.key()==game.mover.Orientation.new().key() and not game.mover.moving and game.mover.held.is_empty() and game.view.current==0,"Reset invalidates movement view and held state")
	await shot("10_reset")
	# Four full rolls along every cardinal axis through the real input pipeline.
	for pair in [[KEY_W,KEY_S],[KEY_D,KEY_A]]:
		await tap(KEY_R)
		var original: String=game.mover.orientation.key()
		await tap(pair[0],4)
		check(game.mover.orientation.key()==original,"runtime forward four-cycle "+str(pair[0]))
		await tap(pair[1],4)
		check(game.mover.cell==Vector2i(0,4) and game.mover.orientation.key()==original,"runtime reverse four-cycle "+str(pair[1]))
	# Check layout at supported minimum size as well as default size.
	root.size=Vector2i(1000,720)
	await delay(0.25)
	await shot("11_minimum_window")
	check(game.overlay.position.y+game.overlay.size.y<game.message.position.y,"minimum window debug panel does not overlap feedback")
	root.size=Vector2i(1280,900)
	await delay(0.25)
	await shot("12_final_default")
	check(game.overlay.position.y+game.overlay.size.y<game.message.position.y,"default window debug panel does not overlap feedback")
	var report: Dictionary={"checks":checks,"failures":failures,"checkpoints":checkpoints,"godot":Engine.get_version_info(),"display":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name()}
	FileAccess.open(evidence.path_join("runtime_report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("PERSPECTIVE_RUNTIME: ",checks," checks; failures=",failures)
	quit(0 if failures.is_empty() else 1)
func key(code: int,pressed: bool) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
	await process_frame
func tap(code: int,count: int=1) -> void:
	for i in count:
		await key(code,true)
		await key(code,false)
		await delay(0.5)
func delay(seconds: float) -> void:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until: await process_frame
func mouse_button(pressed: bool,at: Vector2) -> void:
	var e:=InputEventMouseButton.new()
	e.button_index=MOUSE_BUTTON_LEFT
	e.pressed=pressed
	e.position=at
	Input.parse_input_event(e)
	await process_frame
func mouse_motion(at: Vector2) -> void:
	var e:=InputEventMouseMotion.new()
	e.position=at
	e.button_mask=MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
	await process_frame
func drag(from: Vector2,to: Vector2) -> void:
	await mouse_button(true,from)
	await mouse_motion(to)
	check(game.view.busy and game.view.dragging,"drag preview locks inputs")
	await mouse_button(false,to)
	await delay(0.5)
func shot(label: String) -> void:
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(evidence.path_join(label+".png"))==OK,"capture "+label)
	checkpoints.append({"label":label,"cell":str(game.mover.cell),"pose":game.mover.orientation.key(),"face":str(game.mover.orientation.face_direction()),"view":game.view.current,"world":game.mover.world,"link_active":game.graph.link.active,"projection_distance":game.graph.link.distance,"cube_screen":str(game.cube.position),"face_visible":game.cube.face_visible})
