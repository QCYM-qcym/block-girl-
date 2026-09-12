extends SceneTree
## Regression for user-reported four-view cycle and visually aligned Inner link.
var game
var checks:=0
var failures: Array[String]=[]
var trace: Array=[]
var evidence:="res://tests/gameplay/evidence/bugfix_round1"
var selected_case:="all"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("FAIL: ",label)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence=arg.trim_prefix("--evidence-dir=")
		if arg.begins_with("--case="): selected_case=arg.trim_prefix("--case=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	game=load("res://tests/gameplay/perspective_connection_tech_test.tscn").instantiate()
	root.add_child(game)
	await process_frame
	if selected_case in ["all","rotation"]: await four_views()
	if selected_case in ["all","inner"]: await inner_traversal()
	var result: Dictionary={"case":selected_case,"checks":checks,"failures":failures,"trace":trace,"godot":Engine.get_version_info(),"display":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name()}
	FileAccess.open(evidence.path_join("bugfix_report.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("BUGFIX_ROUND1 ",selected_case,": ",checks," checks; failures=",failures)
	quit(0 if failures.is_empty() else 1)
func four_views() -> void:
	for action in ["E","Q","drag_right","drag_left"]:
		await tap(KEY_R)
		var original: String=game.mover.orientation.key()
		var seen: Dictionary={}
		for step in range(1,5):
			if action=="E": await tap(KEY_E)
			elif action=="Q": await tap(KEY_Q)
			else: await drag(150.0 if action=="drag_right" else -150.0)
			var expected: int=posmod(step if action in ["E","drag_right"] else -step,4)
			check(game.view.current==expected,action+" advances exactly one 90-degree view step "+str(step))
			check(game.mover.cell==Vector2i(0,4) and game.mover.orientation.key()==original and game.mover.world==0,action+" preserves player/world step "+str(step))
			seen[game.view.current]=true
			trace.append({"action":action,"step":step,"view":game.view.current,"expected":expected,"tile_origin":str(game.tiles[Vector2i.ZERO].position),"tile_east":str(game.tiles[Vector2i.RIGHT].position),"pose":original})
			if action=="E": await shot("view_"+str(expected))
		check(seen.size()==4,action+" visits all four views")
		check(game.view.current==0,action+" full cycle returns NORTH")
	# Every input axis projects to the same screen direction in all four views.
	await tap(KEY_R)
	var screen_axes: Array[Vector2]=[Vector2(16,-8),Vector2(16,8),Vector2(-16,8),Vector2(-16,-8)]
	for v in 4:
		if v>0: await tap(KEY_E)
		for axis in 4:
			var world_direction: Vector2i=game.view.world_direction(axis)
			check(game.view.project_delta(Vector2(world_direction),game.view.current)==screen_axes[axis],"screen axis mapping view "+str(v)+" axis "+str(axis))
	await tap(KEY_R)
	await tap(KEY_D,2)
	await tap(KEY_W,2)
	var expected_directions: Array=[
		[Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)],
		[Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)],
		[Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,0)],
		[Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1)]]
	for v in 4:
		if v>0: await tap(KEY_E)
		for axis in 4:
			var before: Vector2i=game.mover.cell
			var screen_before: Vector2=game.cube.global_position
			await tap([KEY_W,KEY_D,KEY_S,KEY_A][axis])
			check(game.mover.cell==before+expected_directions[v][axis],"actual WASD world mapping "+str(v)+"/"+str(axis))
			check(game.cube.global_position-screen_before==screen_axes[axis]*game.scale_factor,"actual WASD screen mapping "+str(v)+"/"+str(axis))
	await tap(KEY_R)
	await drag(800.0)
	check(game.view.current==1,"very long gesture still advances only one view")
	for start_and_step in [[3,1],[0,-1]]:
		var boundary=game.Perspective.new()
		boundary.current=start_and_step[0]
		var angle_before: float=boundary.displayed_angle()
		boundary.request(start_and_step[1])
		boundary.tick(0.2)
		var angular_delta: float=boundary.displayed_angle()-angle_before
		check(is_equal_approx(angular_delta,start_and_step[1]*PI/4),"wrap transition follows signed 90-degree arc")
		boundary.tick(0.3)
		check(boundary.current==posmod(start_and_step[0]+start_and_step[1],4),"wrap commits exact discrete index")
	# Model cycles must not accumulate floating-point gameplay drift.
	var perspective=game.Perspective.new()
	var exact:=true
	for i in 1000:
		perspective.request_rotate_right()
		perspective.tick(1.0)
		if perspective.current!=posmod(i+1,4): exact=false
	check(exact and perspective.current==0,"1000 discrete rotations without drift")
	await tap(KEY_R)
	await tap(KEY_D,4)
	await tap(KEY_W,2)
	for v in 4:
		var pose: String=game.mover.orientation.key()
		var revision: int=game.graph.revision
		await key(KEY_E,true)
		await key(KEY_E,false)
		await key(KEY_W,true)
		await key(KEY_W,false)
		await key(KEY_SPACE,true)
		await key(KEY_SPACE,false)
		await key(KEY_Q,true)
		await key(KEY_Q,false)
		check(game.view.busy and game.view.current==v and game.graph.revision==revision,"rotation keeps committed view/topology "+str(v))
		check(game.mover.cell==Vector2i(4,2) and game.mover.world==0 and game.mover.orientation.key()==pose,"all-view rotation locks movement and Shift "+str(v))
		check(game.graph.neighbor(Vector2i(4,2),Vector2i.RIGHT,game.view)==Vector2i(4,2),"all-view rotation locks traversal "+str(v))
		await delay(0.45)
		check(game.view.current==posmod(v+1,4) and game.graph.revision==revision+1,"single snap commit then one recalc "+str(v))
		check(game.graph.link.active==(game.view.current==1),"only EAST connects after snap")
	# Each discrete map must remain inside the supported game area.
	for window_size in [Vector2i(1280,900),Vector2i(1000,720)]:
		root.size=window_size
		await delay(0.2)
		for v in 4:
			var region:=Rect2(Vector2(355,110),Vector2(window_size.x-370,window_size.y-230))
			var visible:=true
			for tile in game.tiles.values():
				if not region.has_point(tile.global_position): visible=false
			check(visible,"all-view map framing "+str(v)+" at "+str(window_size))
			check(game.overlay.position.y+game.overlay.size.y<game.message.position.y,"debug fits window "+str(window_size))
			await tap(KEY_E)
	root.size=Vector2i(1280,900)
	await delay(0.2)
func inner_traversal() -> void:
	# Configurable restrictions remain meaningful: Surface-only, Inner-only, both.
	var graph=game.Graph.new()
	var view=game.Perspective.new()
	view.current=1
	for allowed in [[0],[1],[0,1]]:
		graph.link.allowed_world_states=allowed
		for world in 2:
			graph.recalculate(view,world)
			check(graph.link.active==(world in allowed),"world policy "+str(allowed)+" world "+str(world))
			check((graph.neighbor(Vector2i(4,2),Vector2i.RIGHT,view)==Vector2i(10,2))==(world in allowed),"graph matches world policy "+str(allowed)+" world "+str(world))
	for attempt in 3:
		await tap(KEY_R)
		await tap(KEY_SPACE)
		await tap(KEY_D,4)
		await tap(KEY_W,2)
		await tap(KEY_E)
		var before:=diagnose("before_inner_cross_"+str(attempt))
		trace.append(before)
		check(game.graph.link.distance<=game.graph.link.projection_tolerance,"Inner anchors visually aligned attempt "+str(attempt))
		check(game.graph.link.active,"Inner valid view and projection activates link attempt "+str(attempt))
		check(before.graph_edge_present,"Inner graph exposes authored edge attempt "+str(attempt))
		check(before.requested_destination=="(10, 2)","Inner neighbor query returns B attempt "+str(attempt))
		check(game.overlay.text.contains("Graph Edge: PRESENT") and game.overlay.text.contains("Player Can Traverse: YES"),"Inner debug agrees with legal traversal")
		if attempt==0: await shot("inner_before_cross")
		var pose: String=game.mover.orientation.key()
		await key(KEY_W,true)
		await key(KEY_W,false)
		await delay(0.12)
		check(game.mover.moving and game.mover.crossing and game.mover.cell==Vector2i(4,2),"Inner starts roll before node commit attempt "+str(attempt))
		if attempt==0: await shot("inner_mid_roll")
		await delay(0.4)
		trace.append(diagnose("after_inner_cross_"+str(attempt)))
		check(game.mover.cell==Vector2i(10,2) and game.mover.orientation.key()!=pose,"Inner completes A to B traversal attempt "+str(attempt))
		if attempt==0: await shot("inner_arrived_b")
		await tap(KEY_Q)
		check(not game.graph.link.active and game.graph.nodes.has(game.mover.cell),"Inner disconnect leaves standing node valid")
		var at: Vector2i=game.mover.cell
		await tap(KEY_A)
		check(game.mover.cell==at,"Inner disabled edge blocks return")
		var preserved_pose: String=game.mover.orientation.key()
		var preserved_view: int=game.view.current
		await tap(KEY_SPACE,2)
		check(game.mover.world==1 and game.mover.cell==at and game.mover.orientation.key()==preserved_pose and game.view.current==preserved_view,"round-trip Shift preserves cell pose and view")
func diagnose(label: String) -> Dictionary:
	var l=game.graph.link
	var neighbors: Array=[]
	for d in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
		var n: Vector2i=game.graph.neighbor(game.mover.cell,d,game.view)
		if n!=game.mover.cell: neighbors.append(str(n))
	return {"label":label,"world":game.mover.world,"view":game.view.current,"rotation_busy":game.view.busy,"player_node":str(game.mover.cell),"grid":str(game.mover.cell),"cube_orientation":game.mover.orientation.key(),"anchor_a":l.a.id,"anchor_b":l.b.id,"a_screen":str(game.view.displayed(l.a.position(),l.a.elevation,l.a.platform)*game.scale_factor+game.board.position),"b_screen":str(game.view.displayed(l.b.position(),l.b.elevation,l.b.platform)*game.scale_factor+game.board.position),"projection_distance":l.distance,"allowed_world_states":l.allowed_world_states.duplicate(),"allowed_perspectives":l.allowed_perspectives.duplicate(),"direction_match":l.entry_direction==l.exit_direction and l.a.direction==l.entry_direction and l.b.direction==-l.exit_direction,"elevation_a":l.a.elevation,"elevation_b":l.b.elevation,"enabled":l.enabled,"active":l.active,"reason":l.reason,"graph_revision":game.graph.revision,"graph_edge_present":game.graph.neighbor(l.a.node,l.entry_direction,game.view)==l.b.node,"neighbor_list":neighbors,"requested_world_direction":str(game.view.world_direction(0)),"requested_destination":str(game.graph.neighbor(game.mover.cell,game.view.world_direction(0),game.view)),"movement_phase":game.mover.phase}
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
		await delay(0.46)
func delay(seconds: float) -> void:
	await create_timer(seconds).timeout
func drag(dx: float) -> void:
	var down:=InputEventMouseButton.new()
	down.button_index=MOUSE_BUTTON_LEFT
	down.pressed=true
	down.position=Vector2(600,450)
	Input.parse_input_event(down)
	await process_frame
	var motion:=InputEventMouseMotion.new()
	motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	motion.position=down.position+Vector2(dx,0)
	Input.parse_input_event(motion)
	await process_frame
	var up:=InputEventMouseButton.new()
	up.button_index=MOUSE_BUTTON_LEFT
	up.position=motion.position
	Input.parse_input_event(up)
	await delay(0.46)
func shot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(label+".png"))
