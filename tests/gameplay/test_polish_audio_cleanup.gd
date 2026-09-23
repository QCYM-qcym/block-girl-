extends SceneTree

const Audio = preload("res://game/polish/p01_audio.gd")
const Cleanup = preload("res://tests/gameplay/helpers/polish_audio_cleanup.gd")
var mode := "normal"
var evidence := ""
var audio_node: Node
var retained: AudioStream
var failures: Array[String] = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): mode = arg.trim_prefix("--case=")
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func setup_audio() -> Array[Dictionary]:
	audio_node = Audio.new()
	root.add_child(audio_node)
	if mode == "retained": retained = audio_node.ambience[0].stream
	# Independently identify the real component's four affected resources.
	var targets: Array[Dictionary] = []
	for player in audio_node.ambience:
		targets.append({"id": str(player.stream.get_instance_id()), "role": "ambience stream"})
		targets.append({"id": str(player.get_stream_playback().get_instance_id()), "role": "ambience playback"})
	var captured := Cleanup.capture_audio(audio_node)
	var captured_ids: Array[String] = []
	for target in captured: captured_ids.append(target.id)
	for target in targets:
		check(target.id in captured_ids, "capture includes the real ambience stream/playback")
	return captured

func all_released(targets: Array[Dictionary]) -> bool:
	for target in targets:
		if is_instance_id_valid(int(target.id)): return false
	return true

func run() -> void:
	if mode not in ["normal", "retained"] or evidence.is_empty():
		printerr("FAIL: require case and evidence directory"); quit(1); return
	DirAccess.make_dir_recursive_absolute(evidence)
	var targets := setup_audio()
	check(targets.size() >= 4 and not all_released(targets), "real ambience resources are initially live")
	audio_node.queue_free()
	audio_node = null
	var frame_limit := 3 if mode == "retained" else 120
	var result: Dictionary = await Cleanup.wait_for_release(self, targets, frame_limit, 2000)
	var recovery: Dictionary = {}
	if mode == "normal":
		check(result.ok and result.exit_code == 0, "normal release permits successful exit")
		check(all_released(targets), "success means actual resource ID invalidation")
	else:
		check(not result.ok and result.exit_code != 0, "retained strong reference prevents successful exit")
		check(result.limit_reached and result.frames == 3, "retained resource reaches fixed frame boundary")
		check(is_instance_id_valid(retained.get_instance_id()), "retained resource remains alive at failure")
		retained = null
		recovery = await Cleanup.wait_for_release(self, targets, 120, 2000)
		check(recovery.ok and all_released(targets), "negative case releases its deliberate reference")
	FileAccess.open(evidence.path_join("cleanup_test.json"), FileAccess.WRITE).store_string(JSON.stringify({"case":mode,"failures":failures,"cleanup":result,"recovery":recovery}, "\t"))
	print("POLISH AUDIO CLEANUP TEST: ", mode, "; failures=", failures)
	# The negative child preserves the failed cleanup's nonzero status even
	# after releasing its deliberate reference for a clean process shutdown.
	quit(1 if not failures.is_empty() else int(result.exit_code))
