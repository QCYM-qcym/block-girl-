extends RefCounted
## Pure record factories. Shape validation is a separate boundary.


static func make_player_location(layer: int, cube_id: StringName, face: int) -> Dictionary:
	return {"layer": layer, "cube_id": cube_id, "face": face}


static func make_player_state(location: Dictionary, orientation: int) -> Dictionary:
	return {"location": location.duplicate(true), "orientation": orientation}


static func make_action(kind: int, payload: Dictionary) -> Dictionary:
	if payload.has("kind"):
		return {}
	var action := payload.duplicate(true)
	action["kind"] = kind
	return action


## Requires validate_level_shape(level) to return no errors.
static func initial_state(level: Dictionary) -> Dictionary:
	var world_orientations: Array[int] = [0, 0]
	for world in level["worlds"]:
		world_orientations[world["layer"]] = world["initial_orientation"]
	var group_orientations: Dictionary = {}
	for group in level["groups"]:
		group_orientations[group["group_id"]] = group["initial_orientation"]
	var mechanism_states: Dictionary = {}
	for mechanism in level["mechanisms"]:
		mechanism_states[mechanism["mechanism_id"]] = mechanism["initial_state"]
	var level_flags: Dictionary = {}
	for flag in level["flag_definitions"]:
		level_flags[flag["flag_id"]] = flag["initial_value"]
	return {
		"player": level["spawn"].duplicate(true),
		"world_orientations": world_orientations,
		"celestial": {"slot_id": level["celestial"]["initial_slot_id"]},
		"group_orientations": group_orientations,
		"mechanism_states": mechanism_states,
		"level_flags": level_flags,
	}
