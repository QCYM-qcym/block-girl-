extends RefCounted

# Test failure boundaries, not animation performance guarantees.
const MAX_FRAMES := 120
const TIMEOUT_MSEC := 2000
var failure := ""
var intermediate := false

func feed(sample: Dictionary, frames: int, elapsed_us: int) -> void:
	if not failure.is_empty(): return
	if not sample.authority_ok:
		failure = "AUTHORITY_CHANGED"
		return
	for tween in sample.tweens:
		if not tween.valid or not tween.running:
			failure = "TWEEN_ENDED_EARLY"
			return
	if intermediate: return
	if frames >= MAX_FRAMES or elapsed_us >= TIMEOUT_MSEC * 1000:
		failure = "INTERMEDIATE_TIMEOUT"
		return
	if sample.tweens.size() != 2 or sample.ghosts.is_empty():
		failure = "MISSING_ANIMATION_OBJECTS"
		return
	if sample.progress >= 1.0:
		failure = "MISSING_INTERMEDIATE"
		return
	var updated: bool = sample.progress > 0.0
	for tween in sample.tweens:
		if not tween.valid or not tween.running:
			failure = "TWEEN_ENDED_EARLY"
			return
		updated = updated and tween.elapsed > 0.0
	for ghost in sample.ghosts:
		if ghost.current == ghost.end:
			failure = "MISSING_INTERMEDIATE"
			return
		updated = updated and ghost.current != ghost.start
	intermediate = updated

const Key = preload("res://foundation/contracts/state_key.gd")
var scene: Node
var tree: SceneTree
var started := false
var created_us := 0
var created_frame := 0
var before_key := ""
var after_key := ""
var before_pose: Dictionary = {}
var after_pose: Dictionary = {}
var commits := 0
var token := 0
var generation := 0
var tweens: Array = []
var tween_finished: Array[bool] = []
var finished_callbacks: Array[Callable] = []
var ghosts: Array[Dictionary] = []
var trace: Array[Dictionary] = []
var commit_events: Array[Dictionary] = []
var manual_commit := false

func attach(runtime: Node) -> void:
	scene = runtime
	tree = runtime.get_tree()
	created_us = Time.get_ticks_usec()
	created_frame = Engine.get_process_frames()
	before_key = Key.build(scene.session.level,scene.session.state).key
	before_pose = pose(scene.presenter)
	commits = scene.session.commit_count
	scene.session.transition_started.connect(_on_started)
	scene.session.committed.connect(_on_committed)
	tree.process_frame.connect(_observe)
	if DisplayServer.get_name() != "headless": RenderingServer.frame_post_draw.connect(_observe)

static func pose(presenter: Node) -> Dictionary:
	var value := {&"@player":presenter.player.transform,&"@celestial":presenter.celestial.transform}
	for id in presenter.cubes: value[id] = presenter.cubes[id].transform
	return value

static func staged_pose(staged: Dictionary) -> Dictionary:
	var value: Dictionary = staged.transforms.duplicate(true)
	value[&"@player"] = staged.player_transform
	value[&"@celestial"] = Transform3D(Basis.IDENTITY,staged.celestial_position)
	return value

func _on_started(result: Dictionary, id: int, gen: int, _global: bool) -> void:
	if started:
		failure = "UNEXPECTED_TRANSITION"
		return
	started = true
	token = id
	generation = gen
	# Runtime's already-connected listener creates both real Tweens first.
	tweens = scene._tweens.duplicate()
	for index in range(tweens.size()):
		tween_finished.append(false)
		var callback := _on_finished.bind(index)
		finished_callbacks.append(callback)
		tweens[index].finished.connect(callback,CONNECT_ONE_SHOT)
	after_key = Key.build(scene.session.level,result.next_state).key
	var source := staged_pose(scene.presenter._stage(scene.session.level,result.previous_state))
	after_pose = staged_pose(scene.presenter._stage(scene.session.level,result.next_state))
	var moving: Array = []
	for key in after_pose:
		if source[key] != after_pose[key]: moving.append(key)
	var groups: Array = scene.presenter.previews.get_children()
	if groups.size() != 1 or groups[0].get_child_count() != moving.size():
		failure = "MISSING_ANIMATION_OBJECTS"
		return
	for index in range(moving.size()):
		var key = moving[index]
		ghosts.append({"node":groups[0].get_child(index),"role":str(key),"start":source[key],"end":after_pose[key]})
	_observe()

func _on_finished(index: int) -> void:
	tween_finished[index] = true

func tween_snapshot() -> Array[Dictionary]:
	var values: Array[Dictionary] = []
	for index in range(tweens.size()):
		var tween: Tween = tweens[index]
		values.append({"role":"ghost" if index == 0 else "progress_and_completion",
			"id":str(tween.get_instance_id()),"valid":tween.is_valid(),
			"running":tween.is_running(),"elapsed":tween.get_total_elapsed_time(),"finished_signal":tween_finished[index]})
	return values

func _on_committed(_state: Dictionary) -> void:
	var event := {"frame":Engine.get_process_frames(),"elapsed_us":Time.get_ticks_usec()-created_us,
		"key":Key.build(scene.session.level,scene.session.state).key,"count":scene.session.commit_count,
		"token":scene.session.transaction_id,"generation":scene.session.generation,
		"progress":scene.presenter.transition_progress,"tweens":tween_snapshot(),"manual":manual_commit}
	commit_events.append(event)
	if not intermediate or event.key != after_key or event.count != commits + 1 or commit_events.size() != 1 or event.generation != generation or event.token != token:
		if failure.is_empty(): failure = "INVALID_COMMIT_BOUNDARY"
	if not manual_commit:
		for tween in event.tweens:
			if tween.elapsed < scene.transition_seconds and failure.is_empty(): failure = "EARLY_NATURAL_COMMIT"
		if event.progress != 1.0 and failure.is_empty(): failure = "EARLY_NATURAL_COMMIT"

func _observe() -> void:
	if not started or not failure.is_empty(): return
	var committed := not commit_events.is_empty()
	var current_key: String = Key.build(scene.session.level,scene.session.state).key
	var sample := {"frame":Engine.get_process_frames(),"elapsed_us":Time.get_ticks_usec()-created_us,
		"key":current_key,"commit_count":scene.session.commit_count,
		"token":scene.session.transaction_id,"generation":scene.session.generation,
		"progress":scene.presenter.transition_progress,"tweens":tween_snapshot(),"ghosts":[],
		"authority_ok":current_key == (after_key if committed else before_key)
			and scene.session.commit_count == commits + (1 if committed else 0)
			and pose(scene.presenter) == (after_pose if committed else before_pose)
			and scene.session.generation == generation and scene.session.transaction_id == token}
	for tween in sample.tweens:
		if (not tween.valid or not tween.running) and not tween.finished_signal:
			failure = "TWEEN_ENDED_EARLY"
	for ghost in ghosts:
		if is_instance_valid(ghost.node):
			sample.ghosts.append({"role":ghost.role,"current":ghost.node.transform,"start":ghost.start,"end":ghost.end})
		elif false in tween_finished and failure.is_empty():
			failure = "GHOST_DISAPPEARED"
	trace.append(sample)
	if not sample.authority_ok:
		failure = "AUTHORITY_CHANGED"
	elif not committed:
		feed(sample,Engine.get_process_frames()-created_frame,sample.elapsed_us)

func wait_intermediate() -> Dictionary:
	while true:
		_observe()
		if not failure.is_empty() or intermediate: return report()
		if at_limit():
			failure = "INTERMEDIATE_TIMEOUT"
			return report()
		# This is only an observation opportunity. Actual Tween/transform data
		# decide success; process_frame itself is before this frame's updates.
		await tree.process_frame
	return {}

func wait_complete() -> Dictionary:
	while true:
		_observe()
		if not failure.is_empty(): return report()
		if at_limit():
			failure = "COMPLETION_TIMEOUT"
			return report()
		var ended := tweens.size() == 2
		for index in range(tweens.size()): ended = ended and tween_finished[index] and not tweens[index].is_running()
		if ended:
			if not intermediate or commit_events.size() != 1 or pose(scene.presenter) != after_pose:
				failure = "INVALID_COMPLETION"
			return report()
		await tree.process_frame
	return {}

func at_limit() -> bool:
	return Engine.get_process_frames()-created_frame >= MAX_FRAMES or Time.get_ticks_usec()-created_us >= TIMEOUT_MSEC * 1000

func report() -> Dictionary:
	return {"ok":failure.is_empty() and intermediate,"failure":failure,"intermediate":intermediate,
		"max_frames":MAX_FRAMES,"timeout_msec":TIMEOUT_MSEC,"frames":Engine.get_process_frames()-created_frame,
		"elapsed_us":Time.get_ticks_usec()-created_us,"trace":trace.duplicate(true),"commits":commit_events.duplicate(true)}

func close() -> void:
	scene.session.transition_started.disconnect(_on_started)
	scene.session.committed.disconnect(_on_committed)
	tree.process_frame.disconnect(_observe)
	if RenderingServer.frame_post_draw.is_connected(_observe): RenderingServer.frame_post_draw.disconnect(_observe)
	ghosts.clear()
	for index in range(tweens.size()):
		if tweens[index].finished.is_connected(finished_callbacks[index]): tweens[index].finished.disconnect(finished_callbacks[index])
	finished_callbacks.clear()
	tweens.clear()
	scene = null
	tree = null
