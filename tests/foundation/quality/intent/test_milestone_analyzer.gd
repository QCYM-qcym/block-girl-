extends SceneTree
const F = preload("res://tests/foundation/quality/intent/intent_fixtures.gd")
const D = preload("res://tests/foundation/quality/intent/solver_contract_double.gd")
var M
var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void:
	var path := "res://foundation/quality/intent/milestone_analyzer.gd"
	if not FileAccess.file_exists(path):
		check(false,"milestone implementation missing")
		finish()
		return
	M = load(path)
	if not M.can_instantiate():
		check(false,"milestone compiles")
		finish()
		return
	var level := F.baked_level(true)
	var w := F.witness(level,[{"kind":0,"face_axis":0}])
	var double := D.new()
	double.setup(level,w)
	var intent := F.empty_intent(level)
	intent.expected_milestones = [F.milestone(&"start",{"kind":0,"face_id":&"floor/TOP"}),F.milestone(&"optional_shift",{"kind":3,"mechanic":1},false),F.milestone(&"move",{"kind":3,"mechanic":0}),F.milestone(&"sun",{"kind":3,"mechanic":6}),F.milestone(&"lit",{"kind":2,"light_state":0}),F.milestone(&"surface",{"kind":1,"layer":0}),F.milestone(&"goal",{"kind":4})]
	var saved := [level.duplicate(true),intent.duplicate(true),w.trace.duplicate(true)]
	var result: Dictionary = M._analyze_with_validator(level,intent,w.trace,double.validate_semantics)
	check(result.status == 0 and result.scope == "SINGLE_TRACE" and result.findings.is_empty(),"single trace match")
	check(result.sample_indices == {&"start":0,&"optional_shift":null,&"move":1,&"sun":1,&"lit":1,&"surface":1,&"goal":1},"nondecreasing required and independent optional literal samples")
	check([level,intent,w.trace] == saved,"milestone preserves inputs")
	intent.expected_milestones = [F.milestone(&"goal",{"kind":4}),F.milestone(&"start",{"kind":0,"face_id":&"floor/TOP"})]
	result = M._analyze_with_validator(level,intent,w.trace,double.validate_semantics)
	check(result.status == 1 and result.missing_required == [&"start"] and result.findings[0].code == 4001,"out of order required bypass witness")
	intent.expected_milestones = [F.milestone(&"shift",{"kind":3,"mechanic":1})]
	result = M._analyze_with_validator(level,intent,w.trace,double.validate_semantics)
	check(result.status == 1 and result.sample_indices[&"shift"] == null,"missing required mechanic milestone")
	intent.expected_milestones[0].required = false
	result = M._analyze_with_validator(level,intent,w.trace,double.validate_semantics)
	check(result.status == 0 and result.findings.is_empty(),"missing optional is not hard error")
	var forged: Dictionary = w.trace.duplicate(true)
	forged.steps[0].action.face_axis = 2
	result = M._analyze_with_validator(level,intent,forged,double.validate_semantics)
	check(result.status == 3 and result.findings == [] and not result.issues.is_empty(),"correct states/keys but unreachable forged action rejected before findings")
	check(double.semantic_calls.size() == 5,"every hard-witness path invokes semantic port")
	var ordinary := F.baked_level()
	var two := F.witness(ordinary,[{"kind":5,"mechanism_id":&"toggle_sky"},{"kind":0,"face_axis":0}])
	var two_double := D.new()
	two_double.setup(ordinary,two)
	var two_intent := F.empty_intent(ordinary)
	two_intent.expected_milestones = [F.milestone(&"move",{"kind":3,"mechanic":0}),F.milestone(&"optional_sun",{"kind":3,"mechanic":6},false),F.milestone(&"late_sun",{"kind":3,"mechanic":6})]
	result = M._analyze_with_validator(ordinary,two_intent,two.trace,two_double.validate_semantics)
	check(result.status == 1 and result.sample_indices == {&"move":2,&"optional_sun":1,&"late_sun":null},"MECHANIC_USED is per-step; optional earliest sample ignores required cursor")
	# Registered fixture gate deliberately approves the fixture only; the real
	# Derived query must still reject an invalid light source, not call it shadow.
	var bad_level := level.duplicate(true)
	bad_level.celestial.slots[0].position2 = Vector3i.ZERO
	double.level = bad_level.duplicate(true)
	intent.expected_milestones = [F.milestone(&"dark",{"kind":2,"light_state":1})]
	result = M._analyze_with_validator(bad_level,intent,w.trace,double.validate_semantics)
	check(result.status == 3 and result.findings.is_empty() and not result.issues[0].upstream.is_empty(),"light query error never matches SHADOW")
	if not FileAccess.file_exists("res://foundation/solver/solution_trace.gd"):
		result = M.analyze_trace(level,F.empty_intent(level),w.trace)
		check(result.status == 3 and result.findings.is_empty(),"public entry has no double fallback")
	finish()

func finish() -> void:
	print("MILESTONE_ANALYZER checks=",checks," failures=",failures)
	if failures.is_empty(): print("MILESTONE_ANALYZER_PROVISIONAL_PASS")
	quit(0 if failures.is_empty() else 1)
