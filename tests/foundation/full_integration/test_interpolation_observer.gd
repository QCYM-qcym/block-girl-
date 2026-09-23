extends SceneTree

const Observer = preload("res://tests/foundation/full_integration/interpolation_observer.gd")
var failures: Array[String] = []
var checks := 0
var evidence := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func sample(progress: float, position: float, authority_ok := true) -> Dictionary:
	return {"authority_ok":authority_ok,"progress":progress,
		"tweens":[{"valid":true,"running":true,"elapsed":progress * 0.5},
			{"valid":true,"running":true,"elapsed":progress * 0.5}],
		"ghosts":[{"current":Transform3D(Basis.IDENTITY,Vector3(position,0,0)),
			"start":Transform3D.IDENTITY,"end":Transform3D(Basis.IDENTITY,Vector3(1,0,0))}]}

func run() -> void:
	var normal = Observer.new()
	normal.feed(sample(0,0),0,0)
	check(not normal.intermediate and normal.failure.is_empty(),"initial is pending")
	normal.feed(sample(0.2,0.2),1,16000)
	check(normal.intermediate and normal.failure.is_empty(),"actual intermediate accepted")
	var stalled = Observer.new()
	for frame in range(Observer.MAX_FRAMES + 1): stalled.feed(sample(0,0),frame,frame * 1000)
	check(stalled.failure == "INTERMEDIATE_TIMEOUT" and not stalled.intermediate,"A initial forever fails at finite frame bound")
	var wall_limit = Observer.new()
	wall_limit.feed(sample(0,0),1,Observer.TIMEOUT_MSEC * 1000)
	check(wall_limit.failure == "INTERMEDIATE_TIMEOUT","A wall-clock bound also fails")
	var jump = Observer.new()
	jump.feed(sample(1,1),1,16000)
	check(jump.failure == "MISSING_INTERMEDIATE" and not jump.intermediate,"B endpoint is not intermediate")
	var corrupt = Observer.new()
	corrupt.feed(sample(0.1,0.1,false),1,16000)
	check(corrupt.failure == "AUTHORITY_CHANGED","C wrong authority fails immediately")
	corrupt.feed(sample(0.2,0.2),2,32000)
	check(corrupt.failure == "AUTHORITY_CHANGED" and not corrupt.intermediate,"C restored authority cannot erase failure")
	var cosmetic = Observer.new()
	cosmetic.feed(sample(0.2,0),1,16000)
	check(not cosmetic.intermediate,"elapsed and progress alone do not prove a transform update")
	var one_tween = Observer.new()
	var one := sample(0.2,0.2)
	one.tweens[0].elapsed = 0.0
	one_tween.feed(one,1,16000)
	check(not one_tween.intermediate,"both Tweens must advance")
	var ended = Observer.new()
	var dead := sample(0.2,0.2)
	dead.tweens[0].running = false
	ended.feed(dead,1,16000)
	check(ended.failure == "TWEEN_ENDED_EARLY","ended Tween fails closed")
	var stopped_later = Observer.new()
	stopped_later.feed(sample(0.2,0.2),1,16000)
	stopped_later.feed(dead,2,32000)
	check(stopped_later.failure == "TWEEN_ENDED_EARLY","early end after intermediate still fails")
	DirAccess.make_dir_recursive_absolute(evidence)
	FileAccess.open(evidence.path_join("observer-tests.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"helper synthetic observations only"},"\t"))
	print("F2_OBSERVER_TESTS checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
