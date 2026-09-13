extends SceneTree
const Fixture = preload("res://prototype/foundation/runtime/runtime_fixture.gd")
const Double = preload("res://tests/foundation/runtime/kernel_double.gd")
const Data = preload("res://foundation/contracts/contract_validation.gd")
const Key = preload("res://foundation/contracts/state_key.gd")
var Session: Script
var Port: Script
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)
func _initialize() -> void:
	for path in ["res://foundation/runtime/runtime_session.gd", "res://foundation/runtime/kernel_port.gd"]:
		if not ResourceLoader.exists(path):
			check(false, "runtime implementation exists: " + path)
			quit(1)
			return
	Session = load("res://foundation/runtime/runtime_session.gd")
	Port = load("res://foundation/runtime/kernel_port.gd")
	if not Session.can_instantiate() or not Port.can_instantiate():
		check(false, "runtime compiles")
		quit(1)
		return
	call_deferred("run")
func setup() -> Array:
	var d := Double.new()
	var s = Session.new(Port.new(d,d,d), d)
	check(s.load_level(Fixture.make_level()).ok, "injected session loads")
	return [s,d]
func finish(s: Variant) -> Dictionary:
	return s.finish_local(s.transaction_id, s.generation)
func run() -> void:
	var level := Fixture.make_level()
	check(level.size() == 19 and Data.validate_level_shape(level).is_empty(), "fixture full DATA shape")
	var production = Session.new()
	check(not production.load_level(level).ok and not production.ready, "missing real dependencies fail closed")
	var pair := setup()
	var s = pair[0]
	var d = pair[1]
	var initial: Dictionary = s.state.duplicate(true)
	check(s.state.size() == 6 and Data.validate_state_shape(level,s.state).is_empty(), "initial state is full valid record")
	level.spawn.orientation = 5
	check(s.level.spawn.orientation == 0, "load owns level copy")
	var malformed := Fixture.make_level()
	malformed.erase("spawn")
	check(not s.load_level(malformed).ok and not s.ready, "DATA rejects invalid load")
	s.load_level(Fixture.make_level())
	d.safety_result = {"status": 2, "issues": []}
	check(not s.load_level(Fixture.make_level()).ok, "Safety unproven fails closed")
	d.safety_result = {"status": 0, "issues": []}
	s.load_level(Fixture.make_level())
	var rejected: Dictionary = s.request_action({"kind":1})
	check(rejected.size() == 8 and rejected.status == 1 and rejected.rejection_code == 1404, "rejected frozen result")
	check(s.state == initial and s.commit_count == 0, "rejection preserves complete state")
	d.override_result = Double.error(initial,{"kind":0,"face_axis":0})
	check(s.request_action({"kind":0,"face_axis":0}).status == 2 and s.state == initial, "ERROR preserves complete state")
	var accepted: Dictionary = s.request_action({"kind":0,"face_axis":0})
	check(s.state == initial and s.commit_count == 0, "local roll defers entire commit")
	var id: int = s.transaction_id
	var gen: int = s.generation
	accepted.next_state.player.orientation = 7
	check(s.request_action({"kind":0,"face_axis":0}).status == 1, "duplicate local input rejected without queue")
	check(not s.finish_local(id,gen).ignored and s.state.player.orientation == 12 and s.commit_count == 1, "local commits owned whole result exactly once")
	check(s.finish_local(id,gen).ignored and s.commit_count == 1, "duplicate callback ignored")
	var moved: Dictionary = s.state.duplicate(true)
	d.override_result = Double.applied(moved,moved,{"kind":0,"face_axis":0})
	s.request_action({"kind":0,"face_axis":0})
	check(s.commit_count == 1 and s.finish_local(s.transaction_id,s.generation).ignored, "no-op creates no animation or commit")
	s.request_action({"kind":2,"rotation_delta":22})
	id = s.transaction_id
	gen = s.generation
	check(s.state == moved and s.context.size() == 3 and s.context.ticket.size() == 3, "global acceptance defers and keeps exact context ticket")
	check(not s.finish_global(id,gen).ignored and s.state.world_orientations == [22,0] and s.state.player.orientation == 15, "global completion commits full endpoint")
	check(s.finish_global(id,gen).ignored and s.commit_count == 2, "global callback commits once")
	s.request_action({"kind":1})
	s.finish_global(s.transaction_id,s.generation)
	check(Key.build(s.level,s.state).key == Key.build(s.level,d.route_states(s.level)[3]).key, "finite route whole StateKey replay parity")
	check(s.state.player.location.layer == 1 and s.state.player.orientation == 15, "shift endpoint retains pose")
	s.reset()
	check(s.state == initial and s.context == d.idle_context(), "reset restores Records initial state")
	s.request_action({"kind":0,"face_axis":0})
	id = s.transaction_id
	gen = s.generation
	s.reset()
	check(s.generation > gen and s.finish_local(id,gen).ignored and s.state == initial, "reset cancels old local token")
	s.request_action({"kind":0,"face_axis":0})
	finish(s)
	s.request_action({"kind":2,"rotation_delta":22})
	id = s.transaction_id
	gen = s.generation
	s.reset()
	check(s.finish_global(id,gen).ignored and s.state == initial, "reset cancels old global token")
	test_busy_and_composite()
	test_port()
	test_malformed_proposals()
	test_observer_reentrancy()
	test_transition_started_reentrancy()
	if failures.is_empty():
		print("FOUNDATION_RUNTIME_SESSION_PASS mode=TEST_DOUBLE checks=",checks)
		quit(0)
	else:
		printerr("RUNTIME_SESSION_FAIL checks=",checks," failures=",failures.size())
		quit(1)
func test_busy_and_composite() -> void:
	var pair := setup()
	var s = pair[0]
	var d = pair[1]
	s.request_action({"kind":0,"face_axis":0})
	finish(s)
	var moved: Dictionary = s.state.duplicate(true)
	s.request_action({"kind":2,"rotation_delta":22})
	var gid: int = s.transaction_id
	var gen: int = s.generation
	var local_after := moved.duplicate(true)
	local_after.player.orientation = 0 # Canned endpoint for scheduler test, no permission claim.
	d.override_result = Double.applied(moved,local_after,{"kind":0,"face_axis":2})
	var captured: Array = []
	s.transition_started.connect(func(_r, token, _g, global):
		if not global: captured.append(token))
	s.request_action({"kind":0,"face_axis":2})
	check(d.calls[-1].context.ticket != null and s.context.local_moves.is_empty(), "busy MOVE delegates context and does not append uncommitted trace")
	check(captured[0] != gid and s.transaction_id == gid, "concurrent local and global tokens stay distinct")
	var final_state := local_after.duplicate(true)
	final_state.world_orientations = [22,0]
	d.completion_result = Double.applied(local_after,final_state,{"kind":2,"rotation_delta":22},2)
	check(s.finish_global(gid,gen).ignored and s.state == moved, "global arrival waits for local roll")
	s.finish_local(captured[0],gen)
	check(s.state == final_state and s.commit_count == 3, "completion preserves latest committed local state")
	check(d.calls[-1].method == "complete_global" and d.calls[-1].state == local_after and d.calls[-1].context.local_moves == [{"kind":0,"face_axis":2}], "completion forwards latest whole state and committed trace")
	check(s.context == d.idle_context() and s.finish_global(gid,gen).ignored, "completion clears transaction")
	# Failed completion must leave latest stable state, never original ticket player.
	s.reset()
	s.request_action({"kind":0,"face_axis":0})
	finish(s)
	s.request_action({"kind":2,"rotation_delta":22})
	d.completion_result = Double.error(s.state,{"kind":2,"rotation_delta":22})
	var before: Dictionary = s.state.duplicate(true)
	check(s.finish_global(s.transaction_id,s.generation).transition.status == 2 and s.state == before and s.context == d.idle_context(), "completion error preserves state and clears activity")
	# Atomic composite result is prerecorded, not an ENTER implementation.
	s.reset()
	var after: Dictionary = d.route_states(s.level)[2]
	d.override_result = Double.applied(s.state,after,{"kind":0,"face_axis":0},2)
	s.request_action({"kind":0,"face_axis":0})
	check(s.context.ticket == null and s.state.player.location.cube_id == &"s0", "composite MOVE opens no global ticket")
	finish(s)
	check(s.state == after and s.commit_count == 1 and s.context.ticket == null, "composite full player and world effect commit once")
func test_port() -> void:
	var unavailable = Port.new()
	check(unavailable.idle_context() == {"global_transition_state":0,"ticket":null,"local_moves":[]}, "unavailable port idle context keeps frozen record shape")
	var issue: Dictionary = unavailable.unavailable_issues()[0]
	check(issue.size() == 6 and issue.has("message"), "dependency issue has full six-field core schema")
	check(Double.error({},{}).issues[0].size() == 6 and Double.error({},{}).issues[0].has("message"), "test double errors keep full core issue schema")
	check(unavailable.is_goal(Fixture.make_level(),{}).is_goal == null, "missing Goal returns frozen null on failure")
	var absent_completion: Dictionary = unavailable.complete_global(Fixture.make_level(),{}, {"global_transition_state":0,"ticket":null,"local_moves":[]})
	check(absent_completion.status == 2 and absent_completion.next_state == null, "missing Kernel completion fails closed for idle context")
	var d := Double.new()
	var p = Port.new(d,d,d)
	var level := Fixture.make_level()
	var states := d.route_states(level)
	var action := {"kind":0,"face_axis":0}
	var context: Dictionary = p.idle_context()
	var result: Dictionary = p.evaluate_action(level,states[0],action,context)
	check(result.status == 0 and result.next_state == states[1], "port forwards four arguments")
	result.next_state.player.orientation = 9
	check(states[1].player.orientation == 12 and p.evaluate_action(level,states[0],action,context).next_state.player.orientation == 12, "port outputs isolated from callers")
	var global_result: Dictionary = p.evaluate_action(level,states[1],{"kind":2,"rotation_delta":22},context)
	var begun: Dictionary = p.begin_global(level,global_result)
	check(begun.ok and p.complete_global(level,states[1],begun.context).next_state == states[2], "port begin and complete signatures")
	check(p.is_goal(level,states[3]).is_goal, "port goal forwards formal signature")


func test_malformed_proposals() -> void:
	var pair := setup()
	var s = pair[0]
	var d = pair[1]
	var before: Dictionary = s.state.duplicate(true)
	var malformed: Dictionary = d.route_states(s.level)[1]
	malformed.player.orientation = 24
	d.override_result = Double.applied(before,malformed,{"kind":0,"face_axis":0})
	var result: Dictionary = s.request_action({"kind":0,"face_axis":0})
	check(result.status == 2 and result.next_state == null and s.state == before, "invalid kernel proposal fails closed before animation")
	s.reset()
	s.request_action({"kind":0,"face_axis":0})
	finish(s)
	s.request_action({"kind":2,"rotation_delta":22})
	before = s.state.duplicate(true)
	d.completion_result = Double.applied(before,malformed,{"kind":2,"rotation_delta":22},2)
	result = s.finish_global(s.transaction_id,s.generation).transition
	check(result.status == 2 and result.next_state == null and s.state == before and s.context.ticket == null, "invalid completion cannot replace latest state")


func test_observer_reentrancy() -> void:
	# A commit observer can synchronously complete a global transition. It must
	# see the new state and its committed MOVE trace together.
	var pair := setup()
	var s = pair[0]
	var d = pair[1]
	s.request_action({"kind":0,"face_axis":0})
	finish(s)
	s.request_action({"kind":2,"rotation_delta":22})
	var gid: int = s.transaction_id
	var gen: int = s.generation
	var local_after: Dictionary = s.state.duplicate(true)
	local_after.player.orientation = 0
	var final_state := local_after.duplicate(true)
	final_state.world_orientations = [22,0]
	d.override_result = Double.applied(s.state,local_after,{"kind":0,"face_axis":2})
	d.completion_result = Double.applied(local_after,final_state,{"kind":2,"rotation_delta":22},2)
	var tokens: Array = []
	s.transition_started.connect(func(_r, id, _g, global):
		if not global: tokens.append(id))
	s.request_action({"kind":0,"face_axis":2})
	s.committed.connect(func(snapshot):
		if snapshot == local_after: s.finish_global(gid,gen), CONNECT_ONE_SHOT)
	s.finish_local(tokens[0],gen)
	check(d.calls[-1].context.local_moves == [{"kind":0,"face_axis":2}], "commit observer sees state and committed trace atomically")
	check(s.state == final_state and s.last_result.action == {"kind":2,"rotation_delta":22}, "reentrant completion feedback is not overwritten by local callback")
	# Reset from a commit signal invalidates every remaining continuation.
	pair = setup()
	s = pair[0]
	d = pair[1]
	var initial: Dictionary = s.state.duplicate(true)
	s.request_action({"kind":0,"face_axis":0})
	s.committed.connect(func(snapshot):
		if snapshot != initial: s.reset(), CONNECT_ONE_SHOT)
	finish(s)
	check(s.state == initial and s.last_result.is_empty() and s.commit_count == 0, "local commit observer Reset suppresses stale feedback")
	# A global commit observer may similarly reload the level.
	pair = setup()
	s = pair[0]
	s.request_action({"kind":0,"face_axis":0})
	finish(s)
	s.request_action({"kind":2,"rotation_delta":22})
	s.committed.connect(func(snapshot):
		if snapshot.world_orientations == [22,0]: s.load_level(Fixture.make_level()), CONNECT_ONE_SHOT)
	s.finish_global(s.transaction_id,s.generation)
	check(s.state == initial and s.last_result.is_empty() and s.commit_count == 0, "global commit observer load suppresses stale feedback")
	# A newly accepted transaction in a commit observer owns subsequent feedback.
	pair = setup()
	s = pair[0]
	d = pair[1]
	s.request_action({"kind":0,"face_axis":0})
	s.committed.connect(func(snapshot):
		if snapshot.world_orientations == [0,0]: s.request_action({"kind":2,"rotation_delta":22}), CONNECT_ONE_SHOT)
	finish(s)
	check(s.context.ticket != null and s.last_result.action == {"kind":2,"rotation_delta":22}, "new observer transaction keeps its acceptance feedback")


func test_transition_started_reentrancy() -> void:
	var pair := setup()
	var s = pair[0]
	var initial: Dictionary = s.state.duplicate(true)
	s.transition_started.connect(func(_r, _id, _gen, _global): s.reset(), CONNECT_ONE_SHOT)
	s.request_action({"kind":0,"face_axis":0})
	check(s.state == initial and s.last_result.is_empty(), "start observer Reset keeps cleared feedback")
	pair = setup()
	s = pair[0]
	s.request_action({"kind":0,"face_axis":0})
	finish(s)
	s.transition_started.connect(func(_r, _id, _gen, _global): s.load_level(Fixture.make_level()), CONNECT_ONE_SHOT)
	s.request_action({"kind":2,"rotation_delta":22})
	check(s.state == initial and s.last_result.is_empty(), "global start observer load keeps cleared feedback")
	pair = setup()
	s = pair[0]
	var local_feedback: Array = []
	s.feedback.connect(func(result): local_feedback.append(result))
	s.transition_started.connect(func(_r, id, gen, _global): s.finish_local(id,gen), CONNECT_ONE_SHOT)
	s.request_action({"kind":0,"face_axis":0})
	check(s.commit_count == 1 and local_feedback.size() == 1, "immediate local completion publishes once without stale acceptance")
	pair = setup()
	s = pair[0]
	s.request_action({"kind":0,"face_axis":0})
	finish(s)
	var global_feedback: Array = []
	s.feedback.connect(func(result): global_feedback.append(result))
	s.transition_started.connect(func(_r, id, gen, _global): s.finish_global(id,gen), CONNECT_ONE_SHOT)
	s.request_action({"kind":2,"rotation_delta":22})
	check(s.commit_count == 2 and global_feedback.size() == 1, "immediate global completion publishes once without stale acceptance")
