extends SceneTree
const Fixture = preload("res://tests/foundation/quality/intent/intent_fixtures.gd")
const Data = preload("res://foundation/contracts/contract_validation.gd")
var Validator
var checks := 0
var failures: Array[String] = []
var level: Dictionary


func _initialize() -> void:
	var path := "res://foundation/quality/intent/intent_validation.gd"
	if not FileAccess.file_exists(path):
		check(false, "IntentValidation implementation missing")
		finish()
		return
	Validator = load(path)
	if Validator == null or not Validator.can_instantiate():
		check(false, "IntentValidation cannot load")
		finish()
		return
	level = Fixture.make_level()
	check(Data.validate_level_shape(level).is_empty(), "fixture is a real LevelDefinition")
	test_valid_inputs()
	test_top_level()
	test_sets()
	test_milestones()
	test_bypasses()
	finish()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func finish() -> void:
	print("INTENT_VALIDATION checks=", checks, " failures=", failures)
	if failures.is_empty():
		print("INTENT_VALIDATION_PASS")
	quit(0 if failures.is_empty() else 1)


func verify(intent: Dictionary, accepted: bool, label: String, code: int = 3016) -> void:
	var saved_intent := intent.duplicate(true)
	var saved_level := level.duplicate(true)
	var result: Dictionary = Validator.validate(level, intent)
	check(result.size() == 2 and result.has_all(["ok", "issues"]), label + " result shape")
	check(typeof(result.get("ok")) == TYPE_BOOL and result.get("ok") == accepted, label + " acceptance")
	check(intent == saved_intent and level == saved_level, label + " inputs unchanged")
	if accepted:
		check(result.issues.is_empty(), label + " no issues")
	else:
		check(not result.issues.is_empty(), label + " has issues")
		for issue in result.issues:
			check(issue.size() == 6 and issue.has_all(["code", "severity", "path", "message", "details", "upstream"]), label + " AnalysisIssue shape")
			check(typeof(issue.code) == TYPE_INT and issue.code == code and issue.severity == 0, label + " issue code/severity")
			check(typeof(issue.path) == TYPE_STRING and not issue.path.is_empty() and typeof(issue.message) == TYPE_STRING and not issue.message.is_empty(), label + " diagnostic location")
			check(issue.details is Dictionary and issue.upstream is Array and issue.upstream.is_empty(), label + " no invented upstream")


func test_valid_inputs() -> void:
	verify(Fixture.make_intent(level), true, "valid default")
	var intent := Fixture.make_intent(level)
	intent.required_mechanics = []
	intent.optional_mechanics = []
	intent.forbidden_bypasses = []
	intent.expected_milestones = []
	verify(intent, true, "all declarations empty")
	intent.required_mechanics = range(8)
	intent.expected_milestones = [
		Fixture.milestone(&"z_first", {"kind": 0, "face_id": &"floor/FRONT"}),
		Fixture.milestone(&"a_second", {"kind": 1, "layer": 1}, false),
		Fixture.milestone(&"lit", {"kind": 2, "light_state": 0}),
		Fixture.milestone(&"shadow", {"kind": 2, "light_state": 1}),
		Fixture.milestone(&"surface", {"kind": 1, "layer": 0}),
		Fixture.milestone(&"used", {"kind": 3, "mechanic": 7}),
		Fixture.milestone(&"goal", {"kind": 4}),
	]
	verify(intent, true, "all predicates and author order")
	intent.forbidden_bypasses = [{"bypass_id": &"a", "disabled_mechanics": [1]}, {"bypass_id": &"b", "disabled_mechanics": [1]}]
	verify(intent, true, "same disabled set different declaration IDs")


func test_top_level() -> void:
	var valid := Fixture.make_intent(level)
	for field in valid:
		var intent := valid.duplicate(true)
		intent.erase(field)
		verify(intent, false, "missing " + field)
		intent = valid.duplicate(true)
		intent[field] = null
		verify(intent, false, "null " + field)
	var extra := valid.duplicate(true)
	extra.dsl = "REACH_SHADOW"
	verify(extra, false, "extra DSL")
	for field in ["intent_version", "level_hash", "rule_version"]:
		var wrong := valid.duplicate(true)
		wrong[field] = "wrong"
		verify(wrong, false, "mismatched " + field, 3010)
		wrong[field] = StringName(valid[field])
		verify(wrong, false, "StringName instead of String " + field)
	for id in [&"", &"Upper", &"1start", &"under-score", &"a/b", &"_prefix", &"space id", "plain_string"]:
		var intent := valid.duplicate(true)
		intent.intent_id = id
		verify(intent, false, "invalid intent ID " + str(id))
	var intent := valid.duplicate(true)
	intent.intent_id = &"a0_valid"
	verify(intent, true, "core ID grammar")


func test_sets() -> void:
	for field in ["required_mechanics", "optional_mechanics"]:
		for bad in [[7, 0], [0, 0], [-1], [8], [1.0], [true], ["1"], PackedInt32Array([1]), {}]:
			var intent := Fixture.make_intent(level)
			intent.required_mechanics = []
			intent.optional_mechanics = []
			intent[field] = bad
			verify(intent, false, "invalid mechanic set " + field + str(bad))
	var overlap := Fixture.make_intent(level)
	overlap.optional_mechanics = [1, 4]
	verify(overlap, false, "required optional overlap")


func test_milestones() -> void:
	for bad in [null, true, [], {}, {"milestone_id": &"a", "required": true}, {"milestone_id": &"a", "required": 1, "predicate": {"kind": 4}}, {"milestone_id": "a", "required": true, "predicate": {"kind": 4}}, {"milestone_id": &"Bad", "required": true, "predicate": {"kind": 4}}, {"milestone_id": &"a", "required": true, "predicate": {"kind": 4}, "extra": 1}]:
		var intent := Fixture.make_intent(level)
		intent.expected_milestones = [bad]
		verify(intent, false, "malformed milestone " + str(bad))
	var duplicate := Fixture.make_intent(level)
	duplicate.expected_milestones.append(duplicate.expected_milestones[0].duplicate(true))
	verify(duplicate, false, "duplicate milestone ID")
	for predicate in [null, "REACH_SHADOW", {}, {"kind": 5}, {"kind": -1}, {"kind": 4.0}, {"kind": true}, {"kind": 4, "text": "GOAL"}, {"kind": 0}, {"kind": 0, "face_id": &"missing/TOP"}, {"kind": 0, "face_id": "floor/TOP"}, {"kind": 0, "face_id": &"floor/top"}, {"kind": 1}, {"kind": 1, "layer": 2}, {"kind": 1, "layer": 0.0}, {"kind": 2}, {"kind": 2, "light_state": 2}, {"kind": 2, "light_state": false}, {"kind": 3}, {"kind": 3, "mechanic": 8}, {"kind": 3, "mechanic": 1.0}, {"kind": 3, "mechanic": 0, "face_id": &"floor/TOP"}]:
		var intent := Fixture.make_intent(level)
		intent.expected_milestones = [{"milestone_id": &"a", "required": true, "predicate": predicate}]
		verify(intent, false, "invalid predicate " + str(predicate))
	for invalid_container in [{}, "milestones"]:
		var intent := Fixture.make_intent(level)
		intent.expected_milestones = invalid_container
		verify(intent, false, "milestone container")


func test_bypasses() -> void:
	for bad in [null, [], {}, {"bypass_id": &"a"}, {"bypass_id": &"Bad", "disabled_mechanics": [1]}, {"bypass_id": "a", "disabled_mechanics": [1]}, {"bypass_id": &"a", "disabled_mechanics": [1], "extra": true}]:
		var intent := Fixture.make_intent(level)
		intent.forbidden_bypasses = [bad]
		verify(intent, false, "malformed bypass " + str(bad))
	for bad in [[], [1, 1], [6, 1], [8], [-1], [1.0], [false], ["1"], PackedInt32Array([1]), {}]:
		var intent := Fixture.make_intent(level)
		intent.forbidden_bypasses = [{"bypass_id": &"a", "disabled_mechanics": bad}]
		verify(intent, false, "invalid disabled set " + str(bad))
	var duplicate := Fixture.make_intent(level)
	duplicate.forbidden_bypasses.append(duplicate.forbidden_bypasses[0].duplicate(true))
	verify(duplicate, false, "duplicate bypass ID")
	duplicate.forbidden_bypasses = {}
	verify(duplicate, false, "bypass container")
