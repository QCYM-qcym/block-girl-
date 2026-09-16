extends SceneTree
const Fixtures = preload("res://tests/foundation/parity/parity_fixtures.gd")
const TraceDouble = preload("res://tests/foundation/parity/trace_contract_double.gd")
const StateKey = preload("res://foundation/contracts/state_key.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
const Orientation = preload("res://foundation/orientation/discrete_orientation.gd")

class ObservedReplayer:
	extends "res://foundation/parity/trace_replayer.gd"
	var starts: Array = []
	var finishes: Array = []
	var drop_completion := false
	var reset_during_animation := false
	var observer := Callable()
	var stale_result: Dictionary = {}
	var reset_session: RefCounted
	func _trace_api() -> Variant:
		return TraceDouble
	func _make_session() -> Variant:
		var owned: RefCounted = super._make_session()
		owned.transition_started.connect(_watch_start.bind(owned))
		return owned
	func _watch_start(result: Dictionary, id: int, generation: int, is_global: bool, owned: RefCounted) -> void:
		starts.append({"action":result.action.duplicate(true),"global_kind":result.global_kind,"id":id,"generation":generation,"is_global":is_global})
		if observer.is_valid(): observer.call(owned,result)
		if reset_during_animation:
			reset_during_animation = false
			reset_session = owned
			get_tree().create_timer(0.04).timeout.connect(func() -> void:
				owned.reset()
				stale_result = owned.finish_global(id,generation) if is_global else owned.finish_local(id,generation))
	func _finish_token(id: int, generation: int, is_global: bool) -> void:
		finishes.append({"id":id,"generation":generation,"is_global":is_global})
		if not drop_completion: super._finish_token(id,generation,is_global)

var failures: Array[String] = []
var checks := 0
var evidence := "res://.godot/foundation-3d/graphics_manual"
var cases: Array = []
var stage: Node3D
var driver: ObservedReplayer
var capture_active := false
var capture_pending := 0
var captures: Array = []
var restarted: Dictionary = {}
var options := {"mode":1,"max_steps":10000,"max_runtime_ms":0,"step_timeout_ms":5000}

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: ",label)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	check(DisplayServer.get_name() != "headless","actual graphical display")
	stage = load("res://tests/foundation/parity/parity_replay_scene.tscn").instantiate()
	root.add_child(stage)
	driver = ObservedReplayer.new()
	stage.add_child(driver)
	driver.observer = _capture_start
	for name in ["multi","one","global","shift","composite","zero"]:
		var fixture: Dictionary = Fixtures.case_named(name)
		check(not fixture.is_empty() and fixture.has_all(["level","trace"]),name+" fixture exists")
		driver.starts.clear()
		driver.finishes.clear()
		capture_active = name == "multi"
		stage.show_evidence("Replaying: "+name,{"actions":fixture.trace.total_actions,"trace_source":"tests-only fixed trace"})
		var before := var_to_bytes(fixture)
		var result: Dictionary = await driver.replay(fixture.level,fixture.trace,options)
		capture_active = false
		check(result.status == 0,name+" natural graphical MATCH: "+str(result))
		check(result.matched_steps == fixture.trace.total_actions and result.divergence_step == null,name+" all semantic steps matched")
		check(var_to_bytes(fixture) == before,name+" inputs unchanged")
		check(driver.starts.size() == fixture.trace.total_actions and driver.finishes.size() == fixture.trace.total_actions,name+" every transition completed through natural Tween.finished")
		check(driver._session.commit_count == fixture.trace.total_actions,name+" one authoritative commit per action")
		check(StateKey.build(fixture.level,driver._session.state).key == fixture.trace.goal_statekey,name+" actual complete goal key")
		for step in driver._step_evidence:
			check(step.commit_delta == 1 and step.commit_signals == 1,name+" one count and signal")
			check(step.expected_statekey == step.actual_statekey,name+" full key equality")
		if name == "composite":
			check(driver.starts.size() == 1 and not driver.starts[0].is_global and driver.starts[0].global_kind == 5,"MOVE+ENTER FaceTransition retains local token and global_kind")
		if name == "multi":
			check(driver.starts.map(func(item: Dictionary) -> bool: return item.is_global) == [false,true,true],"MOVE local / world rotate global / Shift global")
			stage.show_evidence("Goal / MATCH",{"matched_steps":result.matched_steps,"commits":driver._session.commit_count,"statekey":result.actual_statekey})
			await capture("goal")
		cases.append({"name":name,"result":result.duplicate(true),"steps":driver._step_evidence.duplicate(true),"tokens":driver.starts.duplicate(true),"finishes":driver.finishes.duplicate(true)})
		await process_frame
	var one: Dictionary = Fixtures.case_named("one")
	driver.drop_completion = true
	driver.finishes.clear()
	var bounded := options.duplicate()
	bounded.step_timeout_ms = 600
	var dropped: Dictionary = await driver.replay(one.level,one.trace,bounded)
	check(dropped.status == 3 and dropped.matched_steps == 0,"disconnected natural completion is INCOMPLETE")
	check(driver.finishes.size() == 1 and driver._step_evidence[0].commit_delta == 0 and driver._step_evidence[0].commit_signals == 0,"natural tween finished but dropped callback cannot commit")
	cases.append({"name":"disconnected_callback","result":dropped,"steps":driver._step_evidence.duplicate(true)})
	driver.drop_completion = false
	for name in ["one","global"]:
		var fixture: Dictionary = Fixtures.case_named(name)
		driver.reset_during_animation = true
		driver.stale_result = {}
		var reset_result: Dictionary = await driver.replay(fixture.level,fixture.trace,options)
		check(reset_result.status != 0 and reset_result.matched_steps == 0,name+" Reset during tween cannot MATCH")
		check(driver.stale_result.get("ignored",false),name+" stale token/generation ignored")
		check(StateKey.build(fixture.level,driver.reset_session.state).key == StateKey.build(fixture.level,Records.initial_state(fixture.level)).key,name+" stale completion cannot overwrite spawn")
		cases.append({"name":"reset_"+name,"result":reset_result,"stale":driver.stale_result.duplicate(true),"steps":driver._step_evidence.duplicate(true)})
	var recovered: Dictionary = await driver.replay(one.level,one.trace,options)
	check(recovered.status == 0 and driver._session.commit_count == 1,"fresh replay after cancellation naturally MATCHes")
	launch_restart(one,"old")
	var old_callback: Callable = driver._connections[-1][1]
	var old_token: Dictionary = driver._token.duplicate(true)
	stage.remove_child(driver)
	stage.add_child(driver)
	launch_restart(one,"new")
	check(driver._token == old_token,"new Session deliberately reuses numeric token and generation")
	old_callback.call()
	check(driver._session.commit_count == 0,"stale natural callback cannot complete replacement Session with same numeric token")
	while restarted.size() < 2: await process_frame
	check(restarted.old.status == 3 and restarted.new.status == 0,"graphical remove/readd preserves cancellation and replacement MATCH")
	cases.append({"name":"stale_callback_reused_token","old_result":restarted.old,"new_result":restarted.new,"steps":driver._step_evidence.duplicate(true)})
	while capture_pending > 0: await process_frame
	var report := {"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"dependency":"REAL_3A_SOLUTION_TRACE",
		"trace_source":"tests-only fixed records; shortest=false","runtime":"real Session / Kernel / Safety / Presenter; natural Tween.finished only",
		"input_simulation":false,"cases":cases,"screenshots":captures}
	FileAccess.open(evidence.path_join("graphics.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("FOUNDATION_PARITY_GRAPHICS_","PASS" if failures.is_empty() else "FAIL"," checks=",checks)
	driver.observer = Callable()
	stage.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _capture_start(session: RefCounted, proposal: Dictionary) -> void:
	if not capture_active or driver.starts.size() != 1: return
	capture_pending += 1
	var initial_key: String = StateKey.build(session.level,session.state).key
	var initial_transform: Transform3D = driver._presenter.player.transform
	stage.show_evidence("Initial / awaiting natural transition",{"commits":session.commit_count,"statekey":StateKey.build(session.level,session.state).key})
	await capture("initial")
	var group: Node3D = driver._presenter.previews.get_child(0)
	var ghost: Node3D = group.get_child(0)
	# Inspect a rendered intermediate pose rather than assuming timer callbacks
	# occur after Tween processing in that frame. Neither endpoint is sufficient.
	var columns := Orientation.columns(proposal.next_state.player.orientation)
	var endpoint_basis := Basis(Vector3(columns[0]),Vector3(columns[1]),Vector3(columns[2]))
	check(session.commit_count == 0 and StateKey.build(session.level,session.state).key == initial_key,"preview advances before authoritative commit")
	check(driver._presenter.player.transform == initial_transform,"authoritative visual stays committed during preview")
	check(not ghost.basis.is_equal_approx(initial_transform.basis) and not ghost.basis.is_equal_approx(endpoint_basis),"real Tween preview lies between the two discrete endpoint poses")
	stage.show_evidence("Transition preview / logical state still committed",{"commits":session.commit_count,"statekey":StateKey.build(session.level,session.state).key})
	await capture("transition")
	capture_pending -= 1

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := evidence.path_join(label+".png")
	check(root.get_texture().get_image().save_png(path) == OK,"auxiliary screenshot "+label)
	captures.append(path)

func launch_restart(fixture: Dictionary, label: String) -> void:
	restarted[label] = await driver.replay(fixture.level,fixture.trace,options)
