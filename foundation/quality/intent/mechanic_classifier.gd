extends RefCounted
const T = preload("res://foundation/quality/intent/intent_types.gd")
const Data = preload("res://foundation/contracts/contract_validation.gd")
const Types = preload("res://foundation/contracts/foundation_types.gd")
const Rules = preload("res://foundation/rules/rule_records.gd")
const Connectivity = preload("res://foundation/rules/connectivity_resolver.gd")
const Effects = preload("res://foundation/rules/mechanism_effects.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")

static func classify_transition(level: Dictionary, result: Dictionary) -> Dictionary:
	var issues := Data.validate_level_shape(level)
	if not issues.is_empty(): return _failure("level",issues)
	issues = Rules.fields(result,{"status":TYPE_INT,"previous_state":TYPE_DICTIONARY,"next_state":TYPE_DICTIONARY,"action":TYPE_DICTIONARY,"changed":TYPE_BOOL,"rejection_code":TYPE_INT,"issues":TYPE_ARRAY,"global_kind":TYPE_INT},"result")
	if not issues.is_empty(): return _failure("result",issues)
	if result.status != 0 or result.rejection_code != 0 or not result.issues.is_empty(): return _failure("result.status")
	issues = Data.validate_state_shape(level,result.previous_state)
	issues.append_array(Data.validate_state_shape(level,result.next_state))
	issues.append_array(Data.validate_action_shape(level,result.action))
	if not issues.is_empty(): return _failure("result",issues)
	var before: Dictionary = result.previous_state
	var after: Dictionary = result.next_state
	if result.changed != (before != after): return _failure("result.changed")
	if not result.changed:
		return _success([],[]) if result.global_kind == 0 else _failure("result.global_kind")
	if before.level_flags != after.level_flags or before.mechanism_states != after.mechanism_states: return _failure("result.next_state")
	var action: Dictionary = result.action
	var effect: Dictionary = action
	var entry: Dictionary = before.player.location
	var tags: Array = []
	var ids: Array = []
	if action.kind == Types.PuzzleActionKind.MOVE:
		var move := Connectivity.query_move(level,before,action.face_axis)
		if not move.ok: return _failure("result.action",move.issues)
		if move.target_location == null: return _failure("result.action")
		entry = move.target_location
		tags.append(T.MechanicTag.MOVE)
		var entering := Effects.enter_effects(level,_face(before.player.location),_face(entry))
		if entering.size() > 1: return _failure("result.action")
		if not entering.is_empty():
			effect = entering[0].action
			ids.append(entering[0].mechanism_id)
			tags.append(T.MechanicTag.MECHANISM_TRIGGER)
	elif action.kind in [5,6,7]:
		var bound := _find(level.mechanisms,"mechanism_id",action.mechanism_id)
		if bound.is_empty() or bound.trigger != &"USE" or bound.face_id != _face(entry): return _failure("result.action.mechanism_id")
		if action.kind != 5 and action != bound.action: return _failure("result.action")
		effect = bound.action
		ids.append(bound.mechanism_id)
		tags.append(T.MechanicTag.MECHANISM_TRIGGER)
	var global_kind := 0
	var worlds: Array = before.world_orientations.duplicate(true)
	var groups: Dictionary = before.group_orientations.duplicate(true)
	var celestial: Dictionary = before.celestial.duplicate(true)
	var location := entry.duplicate(true)
	match effect.kind:
		0:
			pass
		1:
			if before.player.location.layer == after.player.location.layer: return _failure("result.next_state.player")
			location = after.player.location.duplicate(true)
			global_kind = Types.GlobalTransitionKind.SHIFT
			tags.append(T.MechanicTag.WORLD_SHIFT)
		2,3:
			var layer: int = effect.kind - 2
			if before.world_orientations[layer] == after.world_orientations[layer]: return _failure("result.next_state.world_orientations")
			worlds[layer] = after.world_orientations[layer]
			global_kind = Types.GlobalTransitionKind.WORLD_ROTATION
			tags.append(_effect_tag(effect.kind))
		4:
			var channel := _find(level.face_transitions,"transition_id",effect.transition_id)
			if channel.is_empty() or channel.source_face_id != _face(entry): return _failure("result.action.transition_id")
			var target := _find(level.faces,"face_id",channel.target_face_id)
			if target.cube_id != entry.cube_id: return _failure("result.action.transition_id")
			location.face = target.face
			global_kind = Types.GlobalTransitionKind.FACE_TRANSITION
			tags.append(T.MechanicTag.FACE_TRANSITION)
		6:
			if not before.group_orientations.has(effect.group_id): return _failure("result.action.group_id")
			if before.group_orientations[effect.group_id] != after.group_orientations[effect.group_id]:
				groups[effect.group_id] = after.group_orientations[effect.group_id]
				global_kind = Types.GlobalTransitionKind.GROUP_ROTATION
				tags.append(T.MechanicTag.LOCAL_GROUP_ROTATE)
			elif action.kind != Types.PuzzleActionKind.MOVE:
				return _failure("result.next_state.group_orientations")
		7:
			if before.celestial != after.celestial:
				celestial = after.celestial.duplicate(true)
				global_kind = Types.GlobalTransitionKind.CELESTIAL
				tags.append(T.MechanicTag.CELESTIAL_CHANGE)
		_:
			return _failure("result.action")
	if after.world_orientations != worlds or after.group_orientations != groups or after.celestial != celestial or after.player.location != location or result.global_kind != global_kind:
		return _failure("result.next_state")
	if action.kind != 0 and effect.kind == 7 and before.player != after.player: return _failure("result.next_state.player")
	return _success(tags,ids)

static func _effect_tag(kind: int) -> int:
	# Also supplies static potential-tag context for advisory metadata only.
	return {0:0,1:1,2:2,3:3,4:4,6:5,7:6}.get(kind,-1)

static func _face(location: Dictionary) -> StringName:
	return Geometry.face_id(location.cube_id,location.face)

static func _find(records: Array, field: String, value: Variant) -> Dictionary:
	for record in records:
		if record[field] == value: return record
	return {}

static func _success(tags: Array, ids: Array) -> Dictionary:
	tags.sort()
	ids.sort()
	return {"ok":true,"tags":tags.duplicate(true),"mechanism_ids":ids.duplicate(true),"issues":[]}

static func _failure(path: String, upstream: Array = []) -> Dictionary:
	return {"ok":false,"tags":[],"mechanism_ids":[],"issues":[T._issue(3016,path,"Expected a consistent applied transition.",upstream)]}
