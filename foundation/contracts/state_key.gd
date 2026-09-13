extends RefCounted
## foundation.contract.v1.1: the complete, canonical statekey.v1 identity.
## Structural validation only; no derived state, hashing or rule algorithms.

const Validation = preload("res://foundation/contracts/contract_validation.gd")
const Types = preload("res://foundation/contracts/foundation_types.gd")


static func build(level: Dictionary, state: Dictionary) -> Dictionary:
	var issues := Validation.validate_level_shape(level)
	if not issues.is_empty():
		return _failure(issues)
	_check_text(level, "", issues)
	if not issues.is_empty():
		return _failure(issues)
	issues = Validation.validate_state_shape(level, state)
	if not issues.is_empty():
		return _failure(issues)
	_check_text(state, "", issues)
	if not issues.is_empty():
		return _failure(issues)

	# Spell out the frozen object order; Dictionary iteration never emits fields.
	var location: Dictionary = state.player.location
	var key := 'statekey.v1:{"level_hash":' + _quote(level.content_hash)
	key += ',"rule_version":' + _quote(level.rule_version)
	key += ',"state":{"celestial":{"slot_id":' + _quote(String(state.celestial.slot_id)) + '}'
	key += ',"group_orientations":' + _map(state.group_orientations)
	key += ',"level_flags":' + _map(state.level_flags)
	key += ',"mechanism_states":' + _map(state.mechanism_states)
	key += ',"player":{"location":{"cube_id":' + _quote(String(location.cube_id))
	key += ',"face":' + _quote(Types.FaceDirection.find_key(location.face))
	key += ',"layer":' + _quote(Types.WorldLayer.find_key(location.layer)) + '}'
	key += ',"orientation":' + str(state.player.orientation) + '}'
	key += ',"world_orientations":[' + str(state.world_orientations[0])
	key += ',' + str(state.world_orientations[1]) + ']}}'
	return {"ok": true, "key": key, "issues": []}


static func _failure(issues: Array[Dictionary]) -> Dictionary:
	var owned := issues.duplicate(true)
	# Shape issues already follow path/code/entity_ids. Unicode issues all have
	# the same code and empty entity_ids, so their remaining order is their path.
	owned.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.path != b.path:
			return _text_less(a.path, b.path)
		if a.code != b.code:
			return a.code < b.code
		var count: int = mini(a.entity_ids.size(), b.entity_ids.size())
		for i in count:
			if a.entity_ids[i] != b.entity_ids[i]:
				return _text_less(String(a.entity_ids[i]), String(b.entity_ids[i]))
		if a.entity_ids.size() != b.entity_ids.size():
			return a.entity_ids.size() < b.entity_ids.size()
		return _text_less(a.message, b.message))
	return {"ok": false, "key": "", "issues": owned}


static func _check_text(value: Variant, path: String, issues: Array[Dictionary]) -> void:
	# Only called after shape validation: collections contain schema values,
	# never arbitrary object graphs or UI data. Include non-key level metadata.
	if value is String or value is StringName:
		var text := String(value)
		for i in text.length():
			var scalar := text.unicode_at(i)
			if scalar < 0 or scalar > 0x10ffff or (scalar >= 0xd800 and scalar <= 0xdfff):
				issues.append({"code": Types.ValidationCode.INVALID_TYPE,
					"severity": Types.ValidationSeverity.ERROR, "path": path,
					"entity_ids": [], "message": "Text must contain only Unicode scalar values.",
					"details": {"character_index": i}})
				return
	elif value is Dictionary:
		for field in value:
			var child_path := String(field) if path.is_empty() else path + "." + String(field)
			_check_text(field, child_path, issues)
			_check_text(value[field], child_path, issues)
	elif value is Array:
		for i in value.size():
			_check_text(value[i], path + "[%d]" % i, issues)


static func _text_less(left: String, right: String) -> bool:
	for i in mini(left.length(), right.length()):
		var a := left.unicode_at(i)
		var b := right.unicode_at(i)
		if a != b:
			return a < b
	return left.length() < right.length()


static func _map(values: Dictionary) -> String:
	var ids: Array = values.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return _text_less(String(a), String(b)))
	var members: PackedStringArray = []
	for id in ids:
		var value: Variant = values[id]
		var encoded: String
		if value is StringName:
			encoded = _quote(String(value))
		elif value is bool:
			encoded = "true" if value else "false"
		else:
			encoded = str(value)
		members.append(_quote(String(id)) + ":" + encoded)
	return "{" + ",".join(members) + "}"


static func _quote(value: String) -> String:
	var parts: PackedStringArray = ['"']
	for i in value.length():
		var scalar := value.unicode_at(i)
		match scalar:
			0x22: parts.append('\\"')
			0x5c: parts.append('\\\\')
			0x08: parts.append('\\b')
			0x09: parts.append('\\t')
			0x0a: parts.append('\\n')
			0x0c: parts.append('\\f')
			0x0d: parts.append('\\r')
			_:
				if scalar < 0x20:
					parts.append('\\u%04x' % scalar)
				else:
					parts.append(value.substr(i, 1))
	parts.append('"')
	return "".join(parts)
