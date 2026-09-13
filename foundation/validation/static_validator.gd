extends RefCounted
## Complete declared-domain validation, never player reachability or permission.
## Count budgets are debited before each configuration / top-level semantic query.

const Types = preload("res://foundation/contracts/foundation_types.gd")
const Status = preload("res://foundation/validation/validation_types.gd").ValidationStatus
const Data = preload("res://foundation/contracts/contract_validation.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")
const Spatial = preload("res://foundation/spatial/spatial_validation.gd")
const Mapping = preload("res://foundation/spatial/mapping_query.gd")
const Lighting = preload("res://foundation/celestial/logical_lighting.gd")
const Celestial = preload("res://foundation/celestial/celestial_rules.gd")
const Orientation = preload("res://foundation/orientation/discrete_orientation.gd")
const Safety = preload("res://foundation/validation/safety_queries.gd")
const Code = Types.ValidationCode


static func validate(level: Dictionary, options: Dictionary) -> Dictionary:
	var work := {"issues": [], "configurations_checked": 0, "checks_performed": 0,
		"halted": false, "options": options}
	var option_issues: Array[Dictionary] = []
	Geometry._record(options, {"max_configurations": TYPE_INT, "max_checks": TYPE_INT}, "options", option_issues)
	for field in ["max_configurations", "max_checks"]:
		if options.has(field) and typeof(options[field]) == TYPE_INT and options[field] <= 0:
			Geometry._add(option_issues, Code.INVALID_TYPE, "options." + field, [], "Budget must be a positive integer.")
	_append(work, option_issues)
	if not option_issues.is_empty():
		return _finish(work)
	# Sorting copies gives DATA stable indexed paths without rewriting its issues.
	# Ordered slot_order / rotation_steps remain untouched.
	var canonical: Dictionary = _canonical(level)
	if not _spend(work):
		return _finish(work)
	var shape := Data.validate_level_shape(canonical)
	_append(work, shape)
	if not shape.is_empty():
		return _finish(work)
	if not _spend(work):
		return _finish(work)
	_append(work, _profiles(canonical))
	if not _spend(work):
		return _finish(work)
	# A no-op SET_SLOT validates the complete Celestial definition without
	# confusing unavailable gameplay requests with invalid level data.
	var slot_id: StringName = canonical.celestial.initial_slot_id
	_append(work, Celestial.resolve_slot_request(canonical.celestial, slot_id, Types.CelestialOp.SET_SLOT, slot_id, &"").issues)
	var initial := Records.initial_state(canonical)
	if not _spend(work):
		return _finish(work)
	_append(work, Safety.validate_state(canonical, initial).issues, _context(initial, "spawn"))
	# Mixed-radix cursor: never multiply domain sizes or allocate their product.
	var domains: Array = []
	for world in canonical.worlds:
		domains.append(world.allowed_states)
	for group in canonical.groups:
		domains.append(group.allowed_states)
	var slots: Array = []
	for slot in canonical.celestial.slots:
		slots.append(slot.slot_id)
	domains.append(slots)
	var cursor: Array[int] = []
	cursor.resize(domains.size())
	cursor.fill(0)
	var remaining := true
	while remaining and not work.halted:
		if work.configurations_checked >= options.max_configurations:
			_exhaust(work, "max_configurations")
			break
		work.configurations_checked += 1
		var state := initial.duplicate(true)
		for layer in 2:
			state.world_orientations[layer] = domains[layer][cursor[layer]]
		for index in canonical.groups.size():
			state.group_orientations[canonical.groups[index].group_id] = domains[index + 2][cursor[index + 2]]
		state.celestial.slot_id = domains[-1][cursor[-1]]
		_validate_configuration(canonical, state, work)
		remaining = _advance(cursor, domains)
	return _finish(work)


static func _validate_configuration(level: Dictionary, state: Dictionary, work: Dictionary) -> void:
	var context := _context(state)
	if not _spend(work):
		return
	var snapshot := Geometry.snapshot(level, state)
	if not snapshot.ok:
		_append(work, snapshot.issues, context)
		return # Failed geometry is never sent to overlap / lighting.
	var faces: Array[Dictionary] = []
	faces.assign(level.faces)
	if not _spend(work):
		return
	var spatial_issues := Spatial.validate_snapshot(snapshot, faces)
	_append(work, spatial_issues, context)
	if not spatial_issues.is_empty():
		return # Invalid internal faces are diagnosed before mapping discovery.
	var anchors := _index(snapshot.value.anchors, "face_id")
	var cubes := _index(snapshot.value.cubes, "cube_id")
	var definitions := _index(level.faces, "face_id")
	var authored_cubes := _index(level.cubes, "cube_id")
	var slots := _index(level.celestial.slots, "slot_id")
	var probes: Array[Dictionary] = []
	for face in level.faces:
		if face.walkable:
			probes.append(face)
	# Goal must have support in every configuration, even if not walkable.
	if not definitions[level.goal.face_id].walkable:
		probes.append(definitions[level.goal.face_id])
	for face in probes:
		var probe := _probe(state, face, authored_cubes[face.cube_id].layer)
		if not _spend(work):
			return
		_append(work, Safety.validate_state(level, probe).issues, _context(state, String(face.face_id)))
	for face in level.faces:
		if not _spend(work):
			return
		var lighting := Lighting.query(anchors[face.face_id], slots[state.celestial.slot_id], snapshot.value.cubes)
		_append(work, lighting.issues, _context(state, String(face.face_id)))
		if not face.walkable:
			continue
		if not _spend(work):
			return
		var enabled: Array[int] = []
		enabled.assign(level.shift_compatibilities)
		var collection := Mapping.collect_mapping_candidates(snapshot, faces, face.face_id, 1 - anchors[face.face_id].layer, enabled)
		if not _spend(work):
			return
		_consume_mapping(work, Mapping.resolve_mapping(collection), level, _context(state, String(face.face_id)))
	_validate_declared_motions(level, state, cubes, probes, authored_cubes, work)


static func _consume_mapping(work: Dictionary, resolution: Dictionary, level: Dictionary, context: Dictionary) -> void:
	match resolution.status:
		Types.MappingResolutionStatus.NONE:
			pass # No mapping is a normal spatial fact, not invalid level data.
		Types.MappingResolutionStatus.UNIQUE:
			if _has_enter(level, resolution.mapping.target_face):
				var issues: Array[Dictionary] = []
				Geometry._add(issues, Code.INVALID_ACTION, "mapping", [resolution.mapping.source_face, resolution.mapping.target_face], "Shift target cannot trigger an ENTER global effect.")
				_append(work, issues, context)
		_:
			_append(work, resolution.issues, context)


static func _profiles(level: Dictionary) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	for index in level.worlds.size():
		var world: Dictionary = level.worlds[index]
		if world.allowed_rotation_deltas.is_empty() != world.allowed_rotation_intents.is_empty():
			Geometry._add(issues, Code.INVALID_ACTION, "worlds[%d]" % index, [], "World rotation deltas and intents must both be empty or both declared.")
	for index in level.groups.size():
		for edge_index in level.groups[index].edges.size():
			var edge: Dictionary = level.groups[index].edges[edge_index]
			if Orientation.compose(edge.rotation_delta, edge.from_orientation) != edge.to_orientation:
				Geometry._add(issues, Code.INVALID_ROTATION_EDGE, "groups[%d].edges[%d]" % [index, edge_index], [level.groups[index].group_id], "Declared target must equal compose(delta, source).")
	var enters := {}
	for index in level.mechanisms.size():
		var mechanism: Dictionary = level.mechanisms[index]
		var path := "mechanisms[%d]" % index
		if mechanism.allowed_states != [mechanism.initial_state]:
			Geometry._add(issues, Code.INVALID_ACTION, path + ".allowed_states", [mechanism.mechanism_id], "First-version mechanisms have exactly their immutable initial state.")
		if mechanism.action.kind not in [Types.PuzzleActionKind.MOVE_CELESTIAL, Types.PuzzleActionKind.LOCAL_GROUP_ROTATE, Types.PuzzleActionKind.USE_FACE_TRANSITION]:
			Geometry._add(issues, Code.INVALID_ACTION, path + ".action", [mechanism.mechanism_id], "Bound effect is outside the first-version execution profile.")
		elif mechanism.action.kind in [Types.PuzzleActionKind.MOVE_CELESTIAL, Types.PuzzleActionKind.LOCAL_GROUP_ROTATE] and mechanism.action.mechanism_id != mechanism.mechanism_id:
			Geometry._add(issues, Code.INVALID_REFERENCE, path + ".action.mechanism_id", [mechanism.mechanism_id, mechanism.action.mechanism_id], "Bound effect must reference its owning mechanism.")
		if mechanism.trigger == &"ENTER":
			if not enters.has(mechanism.face_id):
				enters[mechanism.face_id] = []
			enters[mechanism.face_id].append(mechanism.mechanism_id)
	for face_id in enters:
		if enters[face_id].size() > 1:
			var ids: Array[StringName] = []
			ids.assign(enters[face_id])
			Geometry._add(issues, Code.MULTIPLE_GLOBAL_MUTATIONS, "faces." + String(face_id) + ".mechanism_ids", ids, "A face may have at most one ENTER global effect.")
	var faces := _index(level.faces, "face_id")
	for index in level.face_transitions.size():
		_append_transition_profile(level.face_transitions[index], faces, "face_transitions[%d]" % index, issues)
		if _has_enter(level, level.face_transitions[index].target_face_id):
			Geometry._add(issues, Code.INVALID_ACTION, "face_transitions[%d].target_face_id" % index, [level.face_transitions[index].transition_id], "FaceTransition target cannot trigger an ENTER global effect.")
	return Geometry._sorted(issues)


static func _append_transition_profile(transition: Dictionary, faces: Dictionary, path: String, issues: Array[Dictionary]) -> void:
	var source: Dictionary = faces[transition.source_face_id]
	var target: Dictionary = faces[transition.target_face_id]
	if source.cube_id != target.cube_id:
		Geometry._add(issues, Code.INVALID_REFERENCE, path, [transition.transition_id], "FaceTransition endpoints must reference the same cube.")
		return
	if source.face_id == target.face_id or not source.walkable or not target.walkable:
		Geometry._add(issues, Code.INVALID_ROTATION_EDGE, path, [transition.transition_id], "FaceTransition requires different walkable faces of one cube.")
		return
	if transition.rotation_steps.is_empty():
		Geometry._add(issues, Code.INVALID_ROTATION_EDGE, path + ".rotation_steps", [transition.transition_id], "FaceTransition must declare a nonempty quarter-turn path.")
		return
	var frame := Geometry.face_frame(source.face)
	var normal: Vector3i = frame.normal
	var rotation := 0
	for step in transition.rotation_steps:
		var next_normal := Orientation.apply(step, normal)
		if next_normal == normal:
			Geometry._add(issues, Code.INVALID_ROTATION_EDGE, path + ".rotation_steps", [transition.transition_id], "Every transport step must change the current support normal.")
		normal = next_normal
		rotation = Orientation.compose(step, rotation)
	var target_frame := Geometry.face_frame(target.face)
	if normal != target_frame.normal or Orientation.apply(rotation, _face_axis(frame, transition.entry_axis)) != _face_axis(target_frame, transition.exit_axis):
		Geometry._add(issues, Code.INVALID_ROTATION_EDGE, path + ".rotation_steps", [transition.transition_id], "Transport endpoint normal and tangent must match the declared target.")


static func _validate_declared_motions(level: Dictionary, state: Dictionary, resolved: Dictionary, probes: Array[Dictionary], cubes: Dictionary, work: Dictionary) -> void:
	for face in probes:
		var before := _probe(state, face, cubes[face.cube_id].layer)
		for world in level.worlds:
			for delta in world.allowed_rotation_deltas:
				var target := Orientation.compose(delta, state.world_orientations[world.layer])
				if target not in world.allowed_states:
					continue
				var after := before.duplicate(true)
				after.world_orientations[world.layer] = target
				if before.player.location.layer == world.layer:
					after.player.orientation = Orientation.compose(delta, before.player.orientation)
				if not _spend(work):
					return
				_append(work, Safety.validate_motion(level, before, after, {"kind": 2 + world.layer, "rotation_delta": delta}).issues, _context(state, String(face.face_id), "world:%d:%d" % [world.layer, delta]))
		for group in level.groups:
			for edge in group.edges:
				if edge.from_orientation != state.group_orientations[group.group_id] or Orientation.compose(edge.rotation_delta, edge.from_orientation) != edge.to_orientation:
					continue
				var after := before.duplicate(true)
				after.group_orientations[group.group_id] = edge.to_orientation
				var world_rotation: int = state.world_orientations[group.layer]
				var shared_delta := Orientation.compose(world_rotation, Orientation.compose(edge.rotation_delta, Orientation.inverse(world_rotation)))
				if face.cube_id in group.cube_ids:
					after.player.orientation = Orientation.compose(shared_delta, before.player.orientation)
				if not _spend(work):
					return
				# Provenance is unused by geometry; no authorizing mechanism is
				# required for a declared group edge to receive static inspection.
				var action := {"kind": 6, "group_id": group.group_id, "rotation_delta": edge.rotation_delta, "mechanism_id": &"static_safety_probe"}
				_append(work, Safety.validate_motion(level, before, after, action).issues, _context(state, String(face.face_id), "group:%s:%d" % [group.group_id, edge.rotation_delta]))
	var faces := _index(level.faces, "face_id")
	for transition in level.face_transitions:
		var profile: Array[Dictionary] = []
		_append_transition_profile(transition, faces, "face_transitions", profile)
		if not profile.is_empty():
			continue
		var source: Dictionary = faces[transition.source_face_id]
		var target: Dictionary = faces[transition.target_face_id]
		var before := _probe(state, source, cubes[source.cube_id].layer)
		var after := _probe(state, target, cubes[target.cube_id].layer)
		var rotation := 0
		for step in transition.rotation_steps:
			rotation = Orientation.compose(step, rotation)
		var cube_rotation: int = resolved[source.cube_id].orientation
		after.player.orientation = Orientation.compose(cube_rotation, Orientation.compose(rotation, Orientation.inverse(cube_rotation)))
		if not _spend(work):
			return
		_append(work, Safety.validate_motion(level, before, after, {"kind": 4, "transition_id": transition.transition_id}).issues, _context(state, String(source.face_id), "transition:" + String(transition.transition_id)))


static func _probe(state: Dictionary, face: Dictionary, layer: int) -> Dictionary:
	var result := state.duplicate(true)
	result.player = {"location": {"layer": layer, "cube_id": face.cube_id, "face": face.face}, "orientation": 0}
	return result


static func _face_axis(frame: Dictionary, axis: int) -> Vector3i:
	return [frame.u, frame.v, -frame.u, -frame.v][axis]


static func _has_enter(level: Dictionary, face_id: StringName) -> bool:
	for mechanism in level.mechanisms:
		if mechanism.face_id == face_id and mechanism.trigger == &"ENTER":
			return true
	return false


static func _index(records: Array, field: String) -> Dictionary:
	var result := {}
	for record in records:
		result[record[field]] = record
	return result


static func _advance(cursor: Array[int], domains: Array) -> bool:
	for index in range(cursor.size() - 1, -1, -1):
		cursor[index] += 1
		if cursor[index] < domains[index].size():
			return true
		cursor[index] = 0
	return false


static func _context(state: Dictionary, probe: String = "", motion: String = "") -> Dictionary:
	var groups := {}
	for id in state.group_orientations:
		groups[String(id)] = state.group_orientations[id]
	return {"world_orientations": state.world_orientations.duplicate(), "group_orientations": groups,
		"slot_id": String(state.celestial.slot_id), "probe": probe, "motion": motion}


static func _append(work: Dictionary, issues: Array, context: Dictionary = {}) -> void:
	for source in issues:
		var issue: Dictionary = source.duplicate(true)
		if not context.is_empty():
			issue.details["static_configuration"] = context.duplicate(true)
		work.issues.append(issue)


static func _spend(work: Dictionary) -> bool:
	if work.halted:
		return false
	if work.checks_performed >= work.options.max_checks:
		_exhaust(work, "max_checks")
		return false
	work.checks_performed += 1
	return true


static func _exhaust(work: Dictionary, field: String) -> void:
	if work.halted:
		return
	work.halted = true
	var issues: Array[Dictionary] = []
	Geometry._add(issues, Code.VALIDATION_BUDGET_EXCEEDED, "options." + field, [], "The declared domain has not been fully validated.", {"configurations_checked": work.configurations_checked, "checks_performed": work.checks_performed})
	_append(work, issues)


static func _finish(work: Dictionary) -> Dictionary:
	var status := Status.VALID
	var issues: Array[Dictionary] = []
	issues.assign(work.issues)
	for issue in issues:
		if issue.code in [Code.VALIDATION_BUDGET_EXCEEDED, Code.VALIDATION_INCOMPLETE]:
			if status == Status.VALID:
				status = Status.INCOMPLETE
		else:
			status = Status.INVALID
	return {"status": status, "issues": Geometry._sorted(issues), "configurations_checked": work.configurations_checked, "checks_performed": work.checks_performed}


static func _canonical(value: Variant, field: String = "", depth: int = 0) -> Variant:
	# Frozen record nesting is shallow. Deeper/cyclic malformed values need no
	# canonical traversal: DATA rejects their enclosing field's type/schema.
	if depth >= 16:
		return value
	if typeof(value) == TYPE_DICTIONARY:
		var result := {}
		var keys: Array = value.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool:
			return str(a) < str(b) if str(a) != str(b) else typeof(a) < typeof(b))
		for key in keys:
			result[key] = _canonical(value[key], str(key), depth + 1)
		return result
	if typeof(value) != TYPE_ARRAY:
		return value
	var result: Array = []
	for item in value:
		result.append(_canonical(item, "", depth + 1))
	var record_keys := {"worlds": "layer", "cubes": "cube_id", "faces": "face_id", "groups": "group_id", "slots": "slot_id", "mechanisms": "mechanism_id", "face_transitions": "transition_id", "flag_definitions": "flag_id"}
	if record_keys.has(field):
		var key: String = record_keys[field]
		result.sort_custom(func(a: Variant, b: Variant) -> bool:
			if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY and a.has(key) and b.has(key):
				if a[key] != b[key]:
					return _less(a[key], b[key])
			return var_to_str(a) < var_to_str(b))
	elif field == "edges":
		result.sort_custom(_edge_less)
	elif field in ["allowed_states", "allowed_rotation_deltas", "allowed_rotation_intents", "shift_compatibilities", "cube_ids", "mechanism_ids", "required_flags", "tags"]:
		result.sort_custom(_less)
	return result


static func _less(a: Variant, b: Variant) -> bool:
	# Invalid heterogeneous arrays still need a transitive total ordering before
	# DATA diagnoses their types. Never mix numeric and textual comparisons.
	if typeof(a) != typeof(b):
		return typeof(a) < typeof(b)
	if typeof(a) == TYPE_INT and typeof(b) == TYPE_INT:
		return a < b
	return var_to_str(a) < var_to_str(b)


static func _edge_less(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		var fields: Array = ["from_orientation", "rotation_delta", "to_orientation"] if a.has("from_orientation") else ["from_slot_id", "to_slot_id"]
		for field in fields:
			if not a.has(field) or not b.has(field):
				break
			if a[field] != b[field]:
				return _less(a[field], b[field])
	return var_to_str(a) < var_to_str(b)
