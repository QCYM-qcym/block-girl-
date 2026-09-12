extends SceneTree

var failures: Array[String] = []
var checks := 0
var State: Script

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func _initialize() -> void:
	if not ResourceLoader.exists("res://prototype/puzzle_state.gd"):
		check(false, "Prototype state exists and can execute the playable rules")
		quit(1)
		return
	State = load("res://prototype/puzzle_state.gd")
	call_deferred("run")

func walk(s, direction: Vector2i, count: int = 1) -> void:
	for i in count:
		check(s.begin_move(direction), "legal path step %s %s" % [s.cell, direction])
		s.finish_move()

func switch(s) -> void:
	check(s.begin_switch(), "legal same-cell switch")
	s.finish_switch()

func run() -> void:
	var s = State.new()
	check(s.cell == Vector2i(1,9) and s.world == 0, "start on Surface")
	check(not s.begin_move(Vector2i(-1,0)), "void rejects movement")
	check(not s.begin_move(Vector2i(1,1)), "diagonal rejected")
	check(s.begin_move(Vector2i.RIGHT), "begin one roll")
	check(s.cell == Vector2i(1,9), "logical position commits after animation")
	check(not s.begin_switch() and not s.begin_move(Vector2i.RIGHT), "busy actions rejected")
	s.reset()
	s.finish_move()
	check(s.cell == Vector2i(1,9) and s.phase == "idle", "Reset invalidates stale roll completion")
	walk(s, Vector2i.RIGHT, 5)
	walk(s, Vector2i.UP)
	check(not s.begin_move(Vector2i.UP), "Surface broken approach blocked")
	switch(s)
	check(s.cell == Vector2i(6,8) and s.world == 1, "switch preserves exact grid coordinate")
	walk(s, Vector2i.UP)
	check(not s.begin_switch(), "target-world void blocks switching")
	check(s.world == 1 and s.cell == Vector2i(6,7), "rejected switch has no side effect")
	walk(s, Vector2i.UP, 4)
	walk(s, Vector2i.LEFT, 4)
	walk(s, Vector2i.UP, 2)
	check(s.phase == "pressing" and not s.plate_latched, "plate visibly presses before activation")
	s.activate_plate()
	check(s.plate_latched and not s.door_open, "latch starts opening but does not grant passage")
	s.cell = Vector2i(10,4)
	s.world = 0
	check(not s.begin_move(Vector2i.UP), "opening gate remains blocked")
	s.mark_door_open()
	walk(s, Vector2i.UP, 3)
	check(s.phase == "completing", "settled ready exit begins completion")
	s.finish_puzzle()
	check(s.phase == "complete" and not s.begin_switch() and not s.begin_move(Vector2i.DOWN), "complete freezes gameplay")
	s.reset()
	check(not s.plate_latched and not s.door_open and s.world == 0 and s.cell == Vector2i(1,9), "Reset restores every persistent flag")
	s.cell = Vector2i(10,4)
	check(not s.begin_move(Vector2i.UP), "closed gate rejects entry")
	s.cell = Vector2i(10,3)
	s.world = 1
	check(not s.begin_switch(), "closed target-world gate rejects switching")
	s.cell = Vector2i(10,2)
	s.world = 0
	walk(s, Vector2i.UP)
	check(s.phase == "idle", "unready exit cannot complete")
	for phase in ["moving", "switching", "pressing", "completing", "complete"]:
		s.phase = phase
		s.plate_latched = true
		s.reset()
		s.finish_switch()
		s.activate_plate()
		s.finish_puzzle()
		check(s.phase == "idle" and s.world == 0 and not s.plate_latched, "Reset cancels stale " + phase)
	explore()
	print("STATE_TESTS: ", checks, " checks; failures=", failures)
	quit(0 if failures.is_empty() else 1)

# Exhaustive settled-state graph: prove a solution, required world/plate, and no softlocks.
func explore() -> void:
	var initial = State.new()
	var states: Array = [initial]
	var seen: Dictionary = {key(initial): 0}
	var reverse: Dictionary = {}
	var wins: Array[int] = []
	var index := 0
	while index < states.size():
		var source = states[index]
		if source.phase == "complete":
			wins.append(index)
			check(source.plate_latched and source.world == 0, "all winning states require Inner plate and Surface")
		for action in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.ZERO]:
			var next = State.new()
			next.cell = source.cell
			next.world = source.world
			next.plate_latched = source.plate_latched
			next.door_open = source.door_open
			next.phase = source.phase
			var accepted: bool = next.begin_switch() if action == Vector2i.ZERO else next.begin_move(action)
			if not accepted: continue
			if action == Vector2i.ZERO: next.finish_switch()
			else: next.finish_move()
			if next.phase == "pressing": next.activate_plate()
			if next.plate_latched: next.mark_door_open()
			if next.phase == "completing": next.finish_puzzle()
			var id: String = key(next)
			if not seen.has(id):
				seen[id] = states.size()
				states.append(next)
			var dest: int = seen[id]
			if not reverse.has(dest): reverse[dest] = []
			reverse[dest].append(index)
		index += 1
	var solvable: Dictionary = {}
	var pending: Array = wins.duplicate()
	while not pending.is_empty():
		var id: int = pending.pop_back()
		if solvable.has(id): continue
		solvable[id] = true
		pending.append_array(reverse.get(id, []))
	check(not wins.is_empty(), "real map has a winning route")
	check(solvable.size() == states.size(), "every reachable settled state can solve without Reset")
	print("REACHABILITY: ", states.size(), " states; ", solvable.size(), " solvable")

func key(s) -> String:
	return "%s/%s/%s/%s/%s" % [s.cell.x, s.cell.y, s.world, s.plate_latched, s.phase]
