extends RefCounted

# Test failure boundaries, not guarantees about engine reclamation time.
const MAX_FRAMES := 120
const TIMEOUT_MSEC := 2000

static func watch(resource: RefCounted, role: String, targets: Array[Dictionary]) -> void:
	if resource == null: return
	var id := str(resource.get_instance_id())
	for target in targets:
		if target.id == id: return
	# Decimal text preserves the full signed 64-bit ID in JSON. No Ref/WeakRef
	# or bound resource Callable escapes this synchronous helper.
	targets.append({"id":id,"class":resource.get_class(),"role":role})

static func capture_audio(audio: Node) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	for child in audio.get_children():
		if child is AudioStreamPlayer:
			watch(child.stream, str(child.get_path()) + ":stream", targets)
			if child.has_stream_playback():
				watch(child.get_stream_playback(), str(child.get_path()) + ":playback", targets)
	return targets

static func wait_for_release(tree: SceneTree, targets: Array[Dictionary], max_frames: int = MAX_FRAMES, timeout_msec: int = TIMEOUT_MSEC) -> Dictionary:
	var started := Time.get_ticks_usec()
	var frames := 0
	while true:
		var pending: Array[Dictionary] = []
		for target in targets:
			if is_instance_id_valid(int(target.id)): pending.append(target)
		var elapsed := Time.get_ticks_usec() - started
		var limit_reached := frames >= max_frames or elapsed >= timeout_msec * 1000
		var ok := not targets.is_empty() and pending.is_empty() and not limit_reached
		if ok or limit_reached or targets.is_empty():
			return {"ok":ok,"exit_code":0 if ok else 2,"frames":frames,"elapsed_us":elapsed,"limit_reached":limit_reached,"max_frames":max_frames,"timeout_msec":timeout_msec,"watched_count":targets.size(),"targets":targets,"pending":pending,"failure":"" if ok else ("NO_CLEANUP_TARGETS" if targets.is_empty() else "AUDIO_CLEANUP_TIMEOUT")}
		await tree.process_frame
		frames += 1
	return {}
