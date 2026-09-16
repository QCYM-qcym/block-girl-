extends SceneTree
const F = preload("res://tests/foundation/rules/kernel_fixture.gd")
const R = preload("res://foundation/contracts/contract_records.gd")
const K = preload("res://foundation/rules/puzzle_rule_kernel.gd")
const RR = preload("res://foundation/rules/rule_records.gd")
var C
var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func classify(level: Dictionary, state: Dictionary, action: Dictionary, tags: Array, ids: Array = []) -> Dictionary:
	var result := K.evaluate_action(level, state, action, RR.idle_context())
	check(result.status == 0, "real Kernel applies " + str(action) + str(result.issues))
	if result.status != 0: return result
	var saved := [level.duplicate(true), result.duplicate(true)]
	var classified: Dictionary = C.classify_transition(level, result)
	check(classified.ok and classified.tags == tags and classified.mechanism_ids == ids, "literal classification " + str(action) + str(classified))
	check([level,result] == saved, "classifier preserves input")
	classified.tags.append(999)
	check(C.classify_transition(level,result).tags == tags, "result collections owned")
	return result

func _initialize() -> void:
	var path := "res://foundation/quality/intent/mechanic_classifier.gd"
	if not FileAccess.file_exists(path):
		check(false,"classifier implementation missing")
		finish()
		return
	C = load(path)
	if not C.can_instantiate():
		check(false,"classifier compiles")
		finish()
		return
	var level := F.make_level(true)
	var state := R.initial_state(level)
	var move := classify(level,state,{"kind":0,"face_axis":0},[0])
	classify(level,state,{"kind":1},[1])
	classify(level,state,{"kind":2,"rotation_delta":2},[2])
	classify(level,state,{"kind":3,"rotation_delta":2},[3])
	classify(level,state,{"kind":4,"transition_id":&"tip"},[4])
	classify(level,state,{"kind":5,"mechanism_id":&"console"},[6,7],[&"console"])
	classify(level,state,F.celestial_action(),[6,7],[&"console"])
	level = F.group_level(true)
	state = R.initial_state(level)
	classify(level,state,{"kind":6,"group_id":&"bridge","rotation_delta":2,"mechanism_id":&"rotator"},[5,7],[&"rotator"])
	classify(level,state,{"kind":5,"mechanism_id":&"rotator"},[5,7],[&"rotator"])
	var contradictory := K.evaluate_action(level,state,{"kind":5,"mechanism_id":&"rotator"},RR.idle_context())
	contradictory.next_state.group_orientations = state.group_orientations.duplicate(true)
	contradictory.global_kind = 0
	var inconsistent: Dictionary = C.classify_transition(level,contradictory)
	check(not inconsistent.ok and inconsistent.tags == [],"direct group trigger cannot change only player pose while group is unchanged")
	level = F.make_level(true)
	F.add_mechanism(level,&"channel",&"floor/TOP",{"kind":4,"transition_id":&"tip"})
	state = R.initial_state(level)
	classify(level,state,{"kind":5,"mechanism_id":&"channel"},[4,7],[&"channel"])
	for target in [&"a",&"b"]:
		level = F.make_level(true)
		F.add_mechanism(level,&"plate",&"step/TOP",F.celestial_action(&"plate",0,target),&"ENTER")
		state = R.initial_state(level)
		classify(level,state,{"kind":0,"face_axis":0},[0,7] if target == &"a" else [0,6,7],[&"plate"])
	level = F.make_level(true)
	F.add_mechanism(level,&"plate",&"floor/TOP",{"kind":4,"transition_id":&"tip"},&"ENTER")
	state = R.initial_state(level)
	var outward := K.evaluate_action(level,state,{"kind":0,"face_axis":0},RR.idle_context())
	check(outward.status == 0,"real intermediate move")
	if outward.status == 0:
		var entered := classify(level,outward.next_state,{"kind":0,"face_axis":2},[0,4,7],[&"plate"])
		check(entered.status == 0 and entered.next_state.player.location.face == 0,"ENTER channel ends beyond entry TOP face")
	level = F.make_level(true)
	state = R.initial_state(level)
	level.mechanisms[0].action = F.celestial_action(&"console",0,&"a")
	classify(level,state,level.mechanisms[0].action,[])
	for mutation in ["rejected","error","changed","extra","world","global","issues"]:
		var bad := move.duplicate(true)
		match mutation:
			"rejected": bad.status = 1
			"error": bad.status = 2
			"changed": bad.changed = false
			"extra": bad.events = []
			"world": bad.next_state.world_orientations[1] = 2
			"global": bad.global_kind = 1
			"issues": bad.issues = [{"unexpected":true}]
		var classified: Dictionary = C.classify_transition(F.make_level(true),bad)
		check(not classified.ok and classified.tags == [] and classified.mechanism_ids == [] and not classified.issues.is_empty(),"reject inconsistent "+mutation)
	finish()

func finish() -> void:
	print("MECHANIC_CLASSIFIER checks=",checks," failures=",failures)
	if failures.is_empty(): print("MECHANIC_CLASSIFIER_PASS")
	quit(0 if failures.is_empty() else 1)
