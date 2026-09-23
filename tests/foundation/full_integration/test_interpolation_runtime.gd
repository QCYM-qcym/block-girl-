extends SceneTree
## Isolated fault construction. Only this fixture perturbs the real Runtime;
## the complete graphical suite never injects these faults.
const Observer = preload("res://tests/foundation/full_integration/interpolation_observer.gd")
var evidence := ""
var mode := "normal"
var failures: Array[String] = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
		if arg.begins_with("--case="): mode = arg.trim_prefix("--case=")
	call_deferred("run")

func run() -> void:
	if mode not in ["normal","stalled","jump","corrupt","early_end","missing_ghost"] or evidence.is_empty():
		printerr("FAIL: invalid fixture arguments"); quit(1); return
	var scene: Node = load("res://prototype/foundation/runtime/foundation_runtime.tscn").instantiate()
	scene.transition_seconds = 0.0 if mode == "jump" else 0.5
	root.add_child(scene)
	await process_frame
	var observer = Observer.new()
	observer.attach(scene)
	scene._submit({"kind":2,"rotation_delta":22} if mode == "missing_ghost" else {"kind":0,"face_axis":0})
	if mode == "missing_ghost":
		# A rotation moves several previews; retaining the rest must not hide one loss.
		if observer.ghosts.size() < 2: failures.append("negative requires multiple ghosts")
		observer.ghosts[0].node.free()
	if mode == "stalled":
		for tween in scene._tweens: tween.set_speed_scale(0.0)
	if mode == "corrupt":
		var saved: Dictionary = scene.session.state
		scene.session.state = scene.session.last_result.next_state.duplicate(true)
		observer._observe()
		scene.session.state = saved
		observer._observe()
	var observed: Dictionary = await observer.wait_intermediate()
	if mode == "early_end":
		observer.manual_commit = true
		scene.session.finish_local(scene.session.transaction_id,scene.session.generation)
		for tween in scene._tweens: tween.kill()
		observed = await observer.wait_complete()
	if mode == "normal": observed = await observer.wait_complete()
	var expected := {"normal":"","stalled":"INTERMEDIATE_TIMEOUT","jump":"INVALID_COMMIT_BOUNDARY","corrupt":"AUTHORITY_CHANGED","early_end":"TWEEN_ENDED_EARLY","missing_ghost":"GHOST_DISAPPEARED"}
	if observed.failure != expected[mode]: failures.append("wrong observation outcome")
	if mode == "normal" and (not observed.ok or observed.commits.size() != 1): failures.append("missing real natural completion")
	if mode != "normal" and observed.ok: failures.append("fault must not pass")
	observer.close()
	# Clear faulted activity before freeing the fixture; no negative carries over.
	scene._reset()
	scene.free()
	await process_frame
	DirAccess.make_dir_recursive_absolute(evidence)
	FileAccess.open(evidence.path_join("runtime-observation.json"),FileAccess.WRITE).store_string(JSON.stringify({"case":mode,"failures":failures,"observation":observed},"\t"))
	print("F2_RUNTIME_OBSERVER case=",mode," expected=",expected[mode]," failures=",failures)
	for failure in failures: printerr("FAIL: ",failure)
	# Expected negative observations remain nonzero children, separately counted.
	quit(1 if not failures.is_empty() else (0 if observed.ok else 2))
