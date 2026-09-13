extends SceneTree
var game
var checks:=0
var failures: Array[String]=[]
var checkpoints: Array=[]
var evidence:="res://tests/gameplay/evidence/p01_runtime_01"
func _initialize() -> void:
	if not ResourceLoader.exists("res://game/levels/mutsumi/p01_another_world.tscn"):
		printerr("FAIL: independent playable P-01 scene missing"); quit(1); return
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("FAIL: ",label)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence=arg.trim_prefix("--evidence-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	game=load("res://game/levels/mutsumi/p01_another_world.tscn").instantiate()
	root.add_child(game)
	await delay(0.4)
	check(not game.debug.visible and game.hint_label.text=="W A S D","default gameplay hides debug and offers movement hint")
	check(ProjectSettings.get_setting("application/run/main_scene")=="res://game/levels/mutsumi/p01_another_world.tscn","F5 opens playable scene")
	await shot("01_start")
	var results: Array=[]
	for mode in ["keyboard","mouse"]:
		await tap(KEY_R)
		await key(KEY_W,true); await delay(0.8)
		check(game.mover.moves==2 and game.mover.moving,"held movement crosses cell boundaries "+mode)
		await key(KEY_W,false); await delay(0.4)
		check(game.mover.cell==Vector2i(0,2) and not game.mover.moving,"release lands at first shore "+mode)
		await tap(KEY_W)
		check(game.mover.cell==Vector2i(0,2) and game.hint_label.text=="Space","first gap blocks and shows contextual Space "+mode)
		await shot(mode+"_02_surface_gap")
		await tap(KEY_SPACE)
		check(game.board.tiles[Vector2i(0,1)].visible,"Inner bridge visible "+mode)
		await tap(KEY_W)
		var pose: String=game.mover.orientation.key()
		await tap(KEY_SPACE)
		check(game.mover.world==1 and game.mover.orientation.key()==pose and game.feedback.visible,"unsafe shift refused with feedback "+mode)
		await shot(mode+"_03_inner_bridge")
		await tap(KEY_W); await tap(KEY_D,3)
		check(game.mover.cell==Vector2i(3,0) and not game.graph.link.active and game.hints.rotation_hint_seen,"second gap requires rotation "+mode)
		await shot(mode+"_04_middle_gap")
		await mouse(true,Vector2(500,450)); await mouse(false,Vector2(500,450)); await delay(0.3)
		check(not game.hints.rotated and game.view.current==0,"a click/rebound must not consume rotation tutorial "+mode)
		if mode=="keyboard": await tap(KEY_E)
		else: await drag(Vector2(500,450),Vector2(660,450))
		check(game.view.current==1 and game.graph.link.active,"EAST Inner aligns link "+mode)
		await shot(mode+"_05_aligned")
		await key(KEY_W,true); await key(KEY_W,false); await delay(0.12)
		check(game.mover.cell==Vector2i(3,0) and game.mover.crossing,"link traversal is a timed roll "+mode)
		await shot(mode+"_06_crossing")
		await key(KEY_Q,true); await key(KEY_Q,false)
		check(not game.view.busy,"traversal rejects rotation "+mode)
		await delay(0.4)
		check(game.mover.cell==Vector2i(9,0),"crossing commits target node "+mode)
		pose=game.mover.orientation.key()
		await tap(KEY_SPACE)
		check(game.view.current==1 and game.mover.world==0 and game.mover.orientation.key()==pose and not game.graph.link.active,"return Surface keeps perspective and pose "+mode)
		await tap(KEY_W,2)
		check(game.graph.plate_pressed and game.graph.door_open and game.board.plate.state=="pressed","Surface plate visibly opens door "+mode)
		await shot(mode+"_07_plate_open")
		await key(KEY_W,true); await delay(0.1)
		check(game.graph.door_open and game.mover.cell==Vector2i(11,0) and game.board.door.state=="open","door stays fully open during passage "+mode)
		await shot(mode+"_08_gate_crossing")
		await delay(0.28)
		check(not game.graph.door_open and game.mover.cell==Vector2i(12,0),"door closes after landing; hold continues "+mode)
		await key(KEY_W,false); await delay(0.45)
		check(game.graph.complete and game.completion.visible and game.mover.cell==Vector2i(13,0),"automatic Puzzle Complete "+mode)
		await shot(mode+"_09_complete")
		results.append([game.mover.cell,game.mover.world,game.view.current,game.mover.orientation.key(),game.mover.moves,game.graph.door_open,game.graph.complete])
		await tap(KEY_SPACE); await tap(KEY_E); await tap(KEY_S)
		check(game.mover.cell==Vector2i(13,0) and game.mover.world==0 and game.view.current==1,"complete locks gameplay "+mode)
	check(results[0]==results[1],"keyboard and mouse complete with identical gameplay state")
	await tap(KEY_R)
	check(game.mover.cell==Vector2i(0,5) and game.mover.world==0 and game.view.current==0 and not game.graph.door_open and not game.completion.visible and not game.graph.link.active and not game.hints.shifted and not game.hints.rotated,"Reset restores world, view, mechanisms, completion and hints")
	# Reset interrupts the three shared transition phases, including drag preview.
	await key(KEY_W,true); await delay(0.1); await tap(KEY_R)
	check(game.mover.cell==Vector2i(0,5) and game.mover.phase=="idle" and game.mover.order.is_empty(),"Reset cancels roll and held key")
	await key(KEY_SPACE,true); await key(KEY_SPACE,false); await delay(0.08); await tap(KEY_R)
	check(game.mover.world==0 and game.mover.phase=="idle","Reset cancels Shift")
	await key(KEY_E,true); await key(KEY_E,false); await delay(0.1)
	var revision: int=game.graph.revision
	await key(KEY_W,true); await key(KEY_W,false); await key(KEY_SPACE,true); await key(KEY_SPACE,false); await key(KEY_Q,true); await key(KEY_Q,false)
	check(game.view.current==0 and game.graph.revision==revision and game.mover.cell==Vector2i(0,5) and game.mover.world==0,"rotation locks commits, Shift and second rotate")
	await tap(KEY_R)
	check(game.view.current==0 and not game.view.busy,"Reset cancels rotation")
	await mouse(true,Vector2(500,450)); await motion(Vector2(540,450)); await tap(KEY_R)
	await mouse(false,Vector2(650,450)); await delay(0.45)
	check(not game.view.busy and game.view.current==0,"Reset cancels drag with no release ghost")
	for size in [Vector2i(1280,900),Vector2i(900,700)]:
		root.size=size; await delay(0.15)
		for v in 4:
			check(game.view.current==v,"all four view order")
			for tile in game.board.tiles.values():
				if not tile.visible: continue
				var at: Vector2=tile.global_position
				check(at.x>=24 and at.x<=size.x-24 and at.y>=100 and at.y<=size.y-145,"map remains in play area %s/%s"%[size,v])
			await shot("layout_%s_view_%s"%[size.y,v])
			await tap(KEY_E)
	await tap(KEY_F3)
	check(game.debug.visible,"F3 debug available")
	await tap(KEY_F3)
	check(not game.debug.visible,"F3 can be hidden again")
	for expected in [3,2,1,0]:
		await tap(KEY_Q)
		check(game.view.current==expected,"Q rotates to adjacent left view")
	for expected in [3,2,1,0]:
		await drag(Vector2(650,420),Vector2(500,420))
		check(game.view.current==expected,"left drag rotates one adjacent view")
	await drag(Vector2(500,420),Vector2(525,420))
	check(game.view.current==0 and not game.view.busy,"short drag rebounds without rotation")
	await key(KEY_W,true); await delay(0.1)
	game.controls.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await delay(0.6)
	check(game.mover.cell==Vector2i(0,4) and game.mover.order.is_empty(),"focus loss finishes only current roll")
	print("P01 RUNTIME: ",checks," checks, failures=",failures)
	var report={"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"version":Engine.get_version_info(),"playthrough_states":results,"checkpoints":checkpoints}
	var file:=FileAccess.open(evidence.path_join("runtime_report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
func delay(seconds: float) -> void:
	await create_timer(seconds).timeout
func key(code: int,pressed: bool) -> void:
	var event:=InputEventKey.new(); event.physical_keycode=code; event.keycode=code; event.pressed=pressed
	Input.parse_input_event(event)
	await process_frame
func tap(code: int,count: int=1) -> void:
	for i in count:
		await key(code,true); await key(code,false); await delay(0.48)
func mouse(pressed: bool,at: Vector2) -> void:
	var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=at
	Input.parse_input_event(event); await process_frame
func motion(at: Vector2) -> void:
	var event:=InputEventMouseMotion.new(); event.position=at
	Input.parse_input_event(event); await process_frame
func drag(from: Vector2,to: Vector2) -> void:
	await mouse(true,from); await motion(to); await mouse(false,to); await delay(0.5)
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path:=evidence.path_join(label+".png")
	root.get_texture().get_image().save_png(path)
	checkpoints.append({"name":label,"cell":str(game.mover.cell),"world":game.mover.world,"view":game.view.current,"phase":game.mover.phase,"door":game.graph.door_open,"complete":game.graph.complete})
