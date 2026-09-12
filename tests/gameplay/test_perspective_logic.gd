extends SceneTree
var checks := 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: ", label)
func _initialize() -> void:
	for file in ["cube_orientation", "perspective_controller", "connectivity"]:
		if not ResourceLoader.exists("res://prototype/perspective/"+file+".gd"):
			check(false, "missing executable " + file)
			quit(1)
			return
	call_deferred("run")
func run() -> void:
	var Pose = load("res://prototype/perspective/cube_orientation.gd")
	var View = load("res://prototype/perspective/perspective_controller.gd")
	var Graph = load("res://prototype/perspective/connectivity.gd")
	var initial = Pose.new()
	for dir in [Vector2i.UP,Vector2i.DOWN,Vector2i.RIGHT,Vector2i.LEFT]:
		var pose = Pose.new()
		for i in 4: pose.roll(dir)
		check(pose.key() == initial.key(), "four rolls return " + str(dir))
		pose.roll(dir)
		pose.roll(-dir)
		check(pose.key() == initial.key(), "opposites cancel " + str(dir))
	var seen: Dictionary = {}
	var queue: Array = [initial]
	while not queue.is_empty():
		var pose = queue.pop_back()
		if seen.has(pose.key()): continue
		seen[pose.key()] = true
		check(pose.valid(), "proper integer cube rotation")
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.RIGHT,Vector2i.LEFT]:
			var next = pose.copy()
			next.roll(d)
			queue.append(next)
	check(seen.size() == 24, "exactly 24 reachable cube orientations")
	var mixed = Pose.new()
	for d in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]: mixed.roll(d)
	check(mixed.key() != initial.key(), "mixed commutator does not spuriously reset")
	for d in [Vector2i.RIGHT,Vector2i.UP,Vector2i.LEFT,Vector2i.DOWN]: mixed.roll(d)
	check(mixed.key() == initial.key(), "reversed mixed sequence restores pose")
	initial.roll_north()
	check(initial.face_direction() == Vector3i.UP, "local face +Z rolls onto top after north")
	var view = View.new()
	var mappings := [[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT],[Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]]
	for v in 2:
		view.current = v
		for key in 4:
			check(view.world_direction(key) == mappings[v][key], "view mapping %s/%s" % [v,key])
		var up: Vector2 = view.project_delta(view.world_direction(0),v)
		check(up.y < 0, "W projects up in both views")
	var graph = Graph.new()
	view.reset()
	graph.recalculate(view,0)
	check(not graph.link.active, "wrong view inactive")
	check(graph.neighbor(Vector2i(4,2),Vector2i.RIGHT,view) == Vector2i(4,2), "View A gap blocked")
	check(view.request_rotate_right(), "rotation begins")
	view.tick(0.2)
	check(view.current == 0 and view.busy, "view commits only on snap")
	check(not view.request_rotate_left(), "second rotation refused")
	check(graph.neighbor(Vector2i(4,2),Vector2i.RIGHT,view) == Vector2i(4,2), "rotating prevents traversal")
	check(view.tick(0.3), "snap emits a commit")
	graph.recalculate(view,0)
	check(graph.link.active and graph.link.distance <= 1, "authored same-height aligned Surface link active")
	var misleading_seams:=0
	for a_cell in graph.nodes:
		if graph.nodes[a_cell]!=0: continue
		for b_cell in graph.nodes:
			if graph.nodes[b_cell]!=1: continue
			for direction in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
				var projected_next: Vector2=view.project(Vector2(a_cell+direction),0,0,1)
				if projected_next.distance_to(view.project(Vector2(b_cell),0,1,1))<0.01 and graph.neighbor(a_cell,direction,view)!=b_cell:
					misleading_seams+=1
	check(misleading_seams==0,"every visually adjacent platform seam has a legal edge")
	check(graph.neighbor(Vector2i(4,2),Vector2i.RIGHT,view) == Vector2i(10,2), "forward edge")
	check(graph.neighbor(Vector2i(10,2),Vector2i.LEFT,view) == Vector2i(4,2), "reverse edge")
	# Preserve the old disallowed-world regression with an explicit authored policy.
	graph.link.allowed_world_states=[0]
	graph.recalculate(view,1)
	check(not graph.link.active, "wrong world inactive")
	graph.link.allowed_world_states=[0,1]
	graph.link.b.elevation = 1
	graph.recalculate(view,0)
	check(not graph.link.active, "different elevation inactive")
	graph.link.b.elevation = 0
	view.platform_b_offsets[1] += Vector2(0,1)
	graph.recalculate(view,0)
	check(not graph.link.active and graph.link.distance > 1, "misaligned authored pair inactive")
	view.platform_b_offsets[1] -= Vector2(0,1)
	graph.link.exit_direction = Vector2i.UP
	graph.recalculate(view,0)
	check(not graph.link.active, "direction twist forbidden")
	graph.link.exit_direction = Vector2i.RIGHT
	graph.link.b.worlds = [1]
	graph.recalculate(view,0)
	check(not graph.link.active, "anchor world restriction honored")
	graph.link.b.worlds = [0,1]
	graph.link.enabled = false
	graph.recalculate(view,0)
	check(not graph.link.active, "disabled authored link inactive")
	graph.link.enabled = true
	graph.recalculate(view,0)
	var count: int = graph.nodes.size()
	view.request_rotate_left()
	check(graph.link.active, "topology cache unchanged mid-rotation")
	check(graph.neighbor(Vector2i(10,2),Vector2i.LEFT,view) == Vector2i(10,2), "active cached edge still locked during snap")
	view.tick(1.0)
	graph.recalculate(view,0)
	check(not graph.link.active and graph.nodes.has(Vector2i(10,2)) and graph.nodes.size() == count, "disconnect removes edge only, not standing node")
	print("PERSPECTIVE_LOGIC: ",checks," checks; 24 orientations; failures=",failures)
	quit(0 if failures.is_empty() else 1)
