extends RefCounted
## Shared geometric safety owner. No action permission, lighting, busy or Kernel.
const Types = preload("res://foundation/contracts/foundation_types.gd")
const Status = preload("res://foundation/validation/validation_types.gd").SafetyStatus
const Data = preload("res://foundation/contracts/contract_validation.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")
const Spatial = preload("res://foundation/spatial/spatial_validation.gd")
const Orientation = preload("res://foundation/orientation/discrete_orientation.gd")
const Code = Types.ValidationCode
const LO := -2147483648
const HI := 2147483647

static func validate_state(level: Dictionary, state: Dictionary) -> Dictionary:
	var context := _context(level,state)
	return _result(context.status,context.issues)

static func validate_motion(level: Dictionary, before: Dictionary, after: Dictionary, action: Dictionary) -> Dictionary:
	var a := _context(level,before)
	if a.status != Status.SAFE:
		return _result(a.status,a.issues)
	var b := _context(level,after)
	if b.status != Status.SAFE:
		return _result(b.status,b.issues)
	var issues: Array[Dictionary] = []
	for issue in Data.validate_action_shape(level,action):
		# Static edge probes have no triggering mechanism; authorization is not geometry.
		if issue.code == Code.INVALID_REFERENCE and issue.path == "mechanism_id":
			continue
		issues.append(issue)
	if not issues.is_empty():
		return _result(Status.ERROR,issues)
	match action.kind:
		Types.PuzzleActionKind.MOVE:
			return _roll(level,before,after,action,a,b).result
		Types.PuzzleActionKind.ROTATE_SURFACE, Types.PuzzleActionKind.ROTATE_INNER, Types.PuzzleActionKind.LOCAL_GROUP_ROTATE:
			return _rotation(level,before,after,action,a,b).result
		Types.PuzzleActionKind.USE_FACE_TRANSITION:
			return _face_transition(level,before,after,action,a,b)
		Types.PuzzleActionKind.SHIFT_WORLD:
			# Only an actual layer exchange has no same-layer continuous path.
			# Mapping and permission remain separate owner queries.
			if before.player.location.layer == after.player.location.layer or a.snapshot != b.snapshot:
				return _error(Code.INVALID_ACTION,"after",[],"Shift exchanges layers without changing physical geometry.")
			return _result(Status.SAFE,[])
		Types.PuzzleActionKind.MOVE_CELESTIAL:
			if before.player != after.player or a.snapshot != b.snapshot:
				return _error(Code.INVALID_ACTION,"action",[],"Celestial motion cannot move physical bodies.")
			return _result(Status.SAFE,[])
	return _error(Code.INVALID_ACTION,"action",[],"Safety requires the concrete geometric effect action.")

static func validate_concurrent_motion(level: Dictionary, before: Dictionary, after_local: Dictionary, after_global: Dictionary, local_action: Dictionary, global_action: Dictionary) -> Dictionary:
	var local_result := validate_motion(level,before,after_local,local_action)
	if local_result.status != Status.SAFE:
		return local_result
	var global_result := validate_motion(level,before,after_global,global_action)
	if global_result.status != Status.SAFE:
		return global_result
	if local_action.kind != Types.PuzzleActionKind.MOVE:
		return _error(Code.INVALID_ACTION,"local_action",[],"Concurrent safety requires an ordinary roll.")
	if global_action.kind == Types.PuzzleActionKind.MOVE_CELESTIAL:
		return local_result
	if not global_action.kind in [2,3,6]:
		return _unproven([],"The declared geometric motion has no concurrent proof profile.")
	var a := _context(level,before)
	var b := _context(level,after_local)
	var g := _context(level,after_global)
	var roll := _roll(level,before,after_local,local_action,a,b)
	var rotation := _rotation(level,before,after_global,global_action,a,g)
	if rotation.layer != before.player.location.layer:
		return local_result
	var issues: Array[Dictionary] = []
	if rotation.carried:
		var combined := _sweep(roll.box,rotation.pivot,rotation.delta,issues)
		if not issues.is_empty():
			return _result(Status.ERROR,issues)
		for cube in a.snapshot.cubes:
			if cube.layer == rotation.layer and not cube.cube_id in rotation.members and _intersects(combined,_body(_components(cube.center2),issues)):
				return _unproven([cube.cube_id],"Combined local/global swept volumes are not separated.")
	else:
		for moving in rotation.sweeps:
			if _intersects(roll.box,moving.box):
				return _unproven([moving.id],"Outside player's roll intersects a Group swept enclosure.")
	if not issues.is_empty():
		return _result(Status.ERROR,issues)
	return _result(Status.SAFE,[])

static func _context(level: Dictionary, state: Dictionary) -> Dictionary:
	var snapshot := Geometry.snapshot(level,state)
	if not snapshot.ok:
		return {"status":Status.ERROR,"issues":snapshot.issues}
	var faces: Array[Dictionary] = []
	faces.assign(level.faces)
	var issues := Spatial.validate_snapshot(snapshot,faces)
	# A valid geometric snapshot may prove both structural and player penetration
	# errors. Keep those independent diagnoses; malformed/overflow data stops here.
	for issue in issues:
		if not issue.code in [Code.SAME_WORLD_CUBE_OVERLAP,Code.SEALED_WALKABLE_FACE,Code.PLAYER_UNSAFE]:
			return {"status":Status.ERROR,"issues":issues}
	var structural: Array[Dictionary] = issues.duplicate(true)
	issues.clear()
	var location: Dictionary = state.player.location
	var id := Geometry.face_id(location.cube_id,location.face)
	var anchor: Dictionary = _find(snapshot.value.anchors,"face_id",id)
	var definition: Dictionary = _find(level.faces,"face_id",id)
	if not definition.walkable:
		Geometry._add(structural,Code.PLAYER_UNSAFE,"player.location",[id],"Player requires a walkable support face.")
	var center := _offset(_components(anchor.position2),anchor.frame.normal,1,issues)
	var body := _body(center,issues)
	if not issues.is_empty():
		return _result(Status.ERROR,structural + issues)
	for cube in snapshot.value.cubes:
		if cube.layer != location.layer:
			continue
		var obstacle := _body(_components(cube.center2),issues)
		if not issues.is_empty():
			return _result(Status.ERROR,structural + issues)
		if _intersects(body,obstacle):
			Geometry._add(structural,Code.PLAYER_UNSAFE,"player.location",[id,cube.cube_id],"Player open interior penetrates a same-world Cube.")
	if not structural.is_empty():
		return _result(Status.UNSAFE,structural)
	return {"status":Status.SAFE,"issues":[],"snapshot":snapshot.value,"anchor":anchor,"body":body,"center":center}

static func _roll(_level: Dictionary, before: Dictionary, after: Dictionary, action: Dictionary, a: Dictionary, b: Dictionary) -> Dictionary:
	var issues: Array[Dictionary] = []
	var d := _direction(a.anchor.frame,action.face_axis)
	var normal: Vector3i = a.anchor.frame.normal
	var target := _offset(_components(a.anchor.position2),d,2,issues)
	var axis := Vector3i(normal.y*d.z-normal.z*d.y,normal.z*d.x-normal.x*d.z,normal.x*d.y-normal.y*d.x)
	var delta := _quarter(axis)
	if not issues.is_empty():
		return {"result":_result(Status.ERROR,issues)}
	if before.player.location.layer != after.player.location.layer or b.anchor.frame.normal != normal or target != _components(b.anchor.position2) or after.player.orientation != Orientation.compose(delta,before.player.orientation) or a.snapshot != b.snapshot:
		return {"result":_error(Code.INVALID_ACTION,"action",[],"Roll endpoints must follow the actual coplanar support edge and quarter-turn pose.")}
	var pivot := _offset(_components(a.anchor.position2),d,1,issues)
	var box := _sweep(a.body,pivot,delta,issues)
	if not issues.is_empty():
		return {"result":_result(Status.ERROR,issues)}
	for cube in a.snapshot.cubes:
		if cube.layer != before.player.location.layer:
			continue
		# Only the two proven coplanar, equally high supporting cubes are exempt.
		if cube.cube_id in [before.player.location.cube_id,after.player.location.cube_id]:
			continue
		if _intersects(box,_body(_components(cube.center2),issues)):
			return {"result":_unproven([cube.cube_id],"Roll swept enclosure is not separated from an unrelated Cube."),"box":box}
	return {"result":_result(Status.SAFE,[]),"box":box}

static func _rotation(level: Dictionary, before: Dictionary, after: Dictionary, action: Dictionary, a: Dictionary, _b: Dictionary) -> Dictionary:
	var issues: Array[Dictionary] = []
	var members: Array = []
	var pivot: Array = []
	var delta: int = action.rotation_delta
	if not _is_quarter(delta):
		return {"result":_error(Code.INVALID_ACTION,"action.rotation_delta",[],"Swept rotation requires a signed principal quarter-turn.")}
	var expected := before.duplicate(true)
	var layer: int
	if action.kind == Types.PuzzleActionKind.LOCAL_GROUP_ROTATE:
		var group := _find(level.groups,"group_id",action.group_id)
		if group.is_empty():
			return {"result":_error(Code.INVALID_REFERENCE,"action.group_id",[action.group_id],"Unknown RotatableGroup.")}
		layer = group.layer
		members = group.cube_ids.duplicate()
		var world := _find(level.worlds,"layer",layer)
		pivot = _transform(_components(group.pivot2),_components(world.pivot2),before.world_orientations[layer],issues)
		delta = Orientation.compose(before.world_orientations[layer],Orientation.compose(delta,Orientation.inverse(before.world_orientations[layer])))
		expected.group_orientations[action.group_id] = Orientation.compose(action.rotation_delta,before.group_orientations[action.group_id])
	else:
		layer = 0 if action.kind == Types.PuzzleActionKind.ROTATE_SURFACE else 1
		pivot = _components(_find(level.worlds,"layer",layer).pivot2)
		for cube in a.snapshot.cubes:
			if cube.layer == layer:
				members.append(cube.cube_id)
		expected.world_orientations[layer] = Orientation.compose(delta,before.world_orientations[layer])
	var carried: bool = before.player.location.cube_id in members
	if carried:
		expected.player.orientation = Orientation.compose(delta,before.player.orientation)
	if expected != after:
		return {"result":_error(Code.INVALID_ACTION,"after",[],"Rotation candidate does not match its rigid carrier and player endpoints.")}
	if not issues.is_empty():
		return {"result":_result(Status.ERROR,issues)}
	var sweeps: Array[Dictionary] = []
	var obstacles: Array[Dictionary] = []
	for cube in a.snapshot.cubes:
		if cube.layer != layer:
			continue
		var body := _body(_components(cube.center2),issues)
		if cube.cube_id in members:
			sweeps.append({"id":cube.cube_id,"box":_sweep(body,pivot,delta,issues)})
		else:
			obstacles.append({"id":cube.cube_id,"box":body})
	if before.player.location.layer == layer:
		if carried:
			sweeps.append({"id":&"player","box":_sweep(a.body,pivot,delta,issues)})
		else:
			obstacles.append({"id":&"player","box":a.body})
	if not issues.is_empty():
		return {"result":_result(Status.ERROR,issues)}
	var result := _result(Status.SAFE,[])
	for moving in sweeps:
		for obstacle in obstacles:
			if _intersects(moving.box,obstacle.box):
				result = _unproven([moving.id,obstacle.id],"Rigid carrier swept enclosure is not separated from a stationary body.")
	return {"result":result,"layer":layer,"members":members,"pivot":pivot,"delta":delta,"carried":carried,"sweeps":sweeps}

static func _face_transition(level: Dictionary, before: Dictionary, after: Dictionary, action: Dictionary, a: Dictionary, b: Dictionary) -> Dictionary:
	var transition := _find(level.face_transitions,"transition_id",action.transition_id)
	if transition.is_empty():
		return _error(Code.INVALID_REFERENCE,"action.transition_id",[action.transition_id],"Unknown FaceTransition.")
	if a.anchor.face_id != transition.source_face_id or b.anchor.face_id != transition.target_face_id or before.player.location.cube_id != after.player.location.cube_id or before.player.location.layer != after.player.location.layer or a.anchor.face_id == b.anchor.face_id or a.snapshot != b.snapshot:
		return _error(Code.INVALID_ACTION,"action.transition_id",[action.transition_id],"FaceTransition requires its declared distinct endpoints on one Cube.")
	var cube := _find(a.snapshot.cubes,"cube_id",before.player.location.cube_id)
	var center := _components(cube.center2)
	var normal: Vector3i = a.anchor.frame.normal
	var entry := _direction(a.anchor.frame,transition.entry_axis)
	var pose: int = before.player.orientation
	var steps: Array[Dictionary] = []
	# Validate the complete declared trajectory before an uncertain enclosure can
	# return UNPROVEN. Invalid late steps or endpoints always remain errors.
	for step in transition.rotation_steps:
		if not _is_quarter(step):
			return _error(Code.INVALID_ROTATION_EDGE,"face_transitions",[action.transition_id],"Transport step must be a quarter-turn.")
		var delta := Orientation.compose(cube.orientation,Orientation.compose(step,Orientation.inverse(cube.orientation)))
		var next_normal := Orientation.apply(delta,normal)
		if next_normal == normal:
			return _error(Code.INVALID_ROTATION_EDGE,"face_transitions",[action.transition_id],"Transport step must change its support normal.")
		steps.append({"normal":normal,"next_normal":next_normal,"delta":delta})
		normal = next_normal
		entry = Orientation.apply(delta,entry)
		pose = Orientation.compose(delta,pose)
	if transition.rotation_steps.is_empty() or normal != b.anchor.frame.normal or pose != after.player.orientation or entry != _direction(b.anchor.frame,transition.exit_axis):
		return _error(Code.INVALID_ROTATION_EDGE,"face_transitions",[action.transition_id],"Transport accumulated frame and pose do not match the declared exit.")
	var issues: Array[Dictionary] = []
	var segments: Array[Dictionary] = []
	for step in steps:
		var near := _body(_offset(center,step.normal,2,issues),issues)
		var far := _body(_offset(center,step.normal,4,issues),issues)
		var next_far := _body(_offset(center,step.next_normal,4,issues),issues)
		var next_near := _body(_offset(center,step.next_normal,2,issues),issues)
		segments.append_array([_union(near,far),_sweep(far,center,step.delta,issues),_union(next_far,next_near)])
		if not issues.is_empty():
			return _result(Status.ERROR,issues)
	for obstacle in a.snapshot.cubes:
		if obstacle.layer != cube.layer:
			continue
		# At distance 4, (sqrt(2)+sqrt(2))^2=8 < 16 proves radial
		# separation from the support. Linear legs only touch its end face.
		if obstacle.cube_id == cube.cube_id:
			continue
		for segment in segments:
			if _intersects(segment,_body(_components(obstacle.center2),issues)):
				return _unproven([obstacle.cube_id,action.transition_id],"Three-segment transport enclosure is not separated from a neighboring Cube.")
	return _result(Status.SAFE,[])

static func _components(value: Vector3i) -> Array:
	return [int(value.x),int(value.y),int(value.z)]
static func _offset(center: Array, direction: Vector3i, distance: int, issues: Array[Dictionary]) -> Array:
	var result: Array = []
	for axis in 3:
		result.append(int(center[axis]) + int(direction[axis]) * distance)
	_check(result,"PLAYER_OFFSET",issues)
	return result
static func _body(center: Array, issues: Array[Dictionary]) -> Dictionary:
	var low: Array = []
	var high: Array = []
	for axis in 3:
		low.append(int(center[axis]) - 1)
		high.append(int(center[axis]) + 1)
	_check(low,"BODY_MINIMUM",issues)
	_check(high,"BODY_MAXIMUM",issues)
	return {"low":low,"high":high}
static func _intersects(a: Dictionary, b: Dictionary) -> bool:
	for axis in 3:
		if a.high[axis] <= b.low[axis] or b.high[axis] <= a.low[axis]:
			return false
	return true
static func _union(a: Dictionary, b: Dictionary) -> Dictionary:
	var low: Array = []
	var high: Array = []
	for axis in 3:
		low.append(mini(a.low[axis],b.low[axis]))
		high.append(maxi(a.high[axis],b.high[axis]))
	return {"low":low,"high":high}
static func _sweep(body: Dictionary, pivot: Array, delta: int, issues: Array[Dictionary]) -> Dictionary:
	var fixed := -1
	var columns := Orientation.columns(delta)
	for axis in 3:
		if columns[axis][axis] == 1:
			fixed = axis
	var radius := 0
	for axis in 3:
		if axis != fixed:
			# All source scalars are int32; sums are bounded far below int64.
			radius += maxi(absi(int(body.low[axis])-int(pivot[axis])),absi(int(body.high[axis])-int(pivot[axis])))
	var result := body.duplicate(true)
	for axis in 3:
		if axis != fixed:
			result.low[axis] = int(pivot[axis])-radius
			result.high[axis] = int(pivot[axis])+radius
	_check(result.low,"SWEEP_MINIMUM",issues)
	_check(result.high,"SWEEP_MAXIMUM",issues)
	return result
static func _transform(point: Array, pivot: Array, rotation: int, issues: Array[Dictionary]) -> Array:
	var columns := Orientation.columns(rotation)
	var result: Array = []
	for axis in 3:
		var value: int = pivot[axis]
		for column in 3:
			value += int(columns[column][axis]) * (int(point[column])-int(pivot[column]))
		result.append(value)
	_check(result,"SAFETY_PIVOT",issues)
	return result
static func _check(values: Array, operation: String, issues: Array[Dictionary]) -> void:
	for axis in 3:
		if values[axis] < LO or values[axis] > HI:
			Geometry._add(issues,Code.ARITHMETIC_OVERFLOW,"safety.coordinates",[],"Safety logical coordinate exceeds int32.",{"operation":operation,"component":["x","y","z"][axis],"representation":"int32","operands":[values[axis]],"minimum":LO,"maximum":HI})
static func _direction(frame: Dictionary, axis: int) -> Vector3i:
	return [frame.u,frame.v,-frame.u,-frame.v][axis]
static func _quarter(axis: Vector3i) -> int:
	for index in 3:
		if axis[index] != 0:
			return Orientation.quarter_turn(index,axis[index])
	return -1
static func _is_quarter(delta: int) -> bool:
	for axis in 3:
		for sign_value in [-1,1]:
			if delta == Orientation.quarter_turn(axis,sign_value):
				return true
	return false
static func _find(records: Array, key: String, value: Variant) -> Dictionary:
	for record in records:
		if record[key] == value:
			return record
	return {}
static func _result(status: int, issues: Array) -> Dictionary:
	var copy: Array[Dictionary] = []
	copy.assign(issues.duplicate(true))
	return {"status":status,"issues":Geometry._sorted(copy)}
static func _error(code: int, path: String, ids: Array[StringName], message: String, status: int = Status.ERROR) -> Dictionary:
	var issues: Array[Dictionary] = []
	Geometry._add(issues,code,path,ids,message)
	return _result(status,issues)
static func _unproven(ids: Array[StringName], message: String) -> Dictionary:
	return _error(Code.VALIDATION_INCOMPLETE,"safety.motion",ids,message,Status.UNPROVEN)
