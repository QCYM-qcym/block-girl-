extends Node3D
## All poses come from a committed PuzzleState through the formal geometry/math
## owners. Node transforms and transition progress are display-only outputs.
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")
const Math = preload("res://foundation/orientation/discrete_orientation.gd")
var player: Node3D
var celestial: MeshInstance3D
var cubes: Dictionary = {}
var frame: Dictionary = {}
var transition_progress := 0.0
var sync_count := 0
var previews: Node3D

func _stage(level: Dictionary, state: Dictionary) -> Dictionary:
	var snapshot := Geometry.snapshot(level, state)
	if not snapshot.ok:
		return {"ok": false, "issues": snapshot.issues}
	var location: Dictionary = state.player.location
	var anchor_id := Geometry.face_id(location.cube_id, location.face)
	var anchor: Dictionary = {}
	for candidate in snapshot.value.anchors:
		if candidate.face_id == anchor_id:
			anchor = candidate
	# DATA guarantees declared slot/location references; stage everything before
	# touching the nodes so a rejected snapshot cannot partially update the view.
	var slot: Dictionary = {}
	for candidate in level.celestial.slots:
		if candidate.slot_id == state.celestial.slot_id:
			slot = candidate
	if anchor.is_empty() or slot.is_empty():
		return {"ok": false, "issues": [{"code": 1006, "severity": 0,
			"path": "presenter", "entity_ids": [], "message": "Unresolved visual reference.", "details": {}}]}
	var player_transform := Transform3D(pose_basis(state.player.orientation),
		(Vector3(anchor.position2) + Vector3(anchor.frame.normal)) * 0.5 + layer_offset(location.layer))
	var transforms: Dictionary = {}
	for cube in snapshot.value.cubes:
		transforms[cube.cube_id] = Transform3D(pose_basis(cube.orientation), Vector3(cube.center2) * 0.5 + layer_offset(cube.layer))
	return {"ok": true, "issues": [], "transforms": transforms, "cube_records": snapshot.value.cubes,
		"player_transform": player_transform, "celestial_position": Vector3(slot.position2) * 0.5, "frame": anchor.frame}

func sync_state(level: Dictionary, state: Dictionary) -> Dictionary:
	var staged := _stage(level, state)
	if not staged.ok:
		return {"ok": false, "issues": staged.issues}
	var transforms: Dictionary = staged.transforms
	if player == null:
		player = Node3D.new()
		player.name = "PlayerPose"
		add_child(player)
		player.add_child(box(Vector3(0.72,0.72,0.72), Color("f7e0a3")))
		var up_mark := box(Vector3(0.5,0.045,0.22), Color("e75e79"))
		up_mark.position.y = 0.38
		player.add_child(up_mark)
		var front_mark := box(Vector3(0.18,0.38,0.045), Color("172740"))
		front_mark.position.z = 0.38
		player.add_child(front_mark)
		celestial = MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.15
		sphere.height = 0.3
		celestial.mesh = sphere
		celestial.material_override = material(Color("ffd877"))
		add_child(celestial)
	for id in cubes.keys():
		if not transforms.has(id):
			cubes[id].queue_free()
			cubes.erase(id)
	for cube in staged.cube_records:
		if not cubes.has(cube.cube_id):
			var node := box(Vector3(0.96,0.96,0.96), Color("559bab") if cube.layer == 0 else Color("8971bd"))
			node.name = String(cube.cube_id)
			add_child(node)
			var label := Label3D.new()
			label.text = String(cube.cube_id)
			label.font_size = 38
			label.pixel_size = 0.004
			label.position = Vector3(0,-0.22,0.49)
			node.add_child(label)
			cubes[cube.cube_id] = node
		cubes[cube.cube_id].transform = transforms[cube.cube_id]
	player.transform = staged.player_transform
	celestial.position = staged.celestial_position
	frame = staged.frame.duplicate(true)
	sync_count += 1
	return {"ok": true, "issues": []}

func animate_transition(level: Dictionary, result: Dictionary, duration: float) -> Dictionary:
	# Ghost meshes interpolate between two authorized records. Stable meshes and
	# the input frame stay committed; this trajectory is never a safety query.
	var before := _stage(level, result.previous_state)
	var after := _stage(level, result.next_state)
	if not before.ok or not after.ok:
		return {"ok": false, "issues": before.issues + after.issues}
	if previews == null:
		previews = Node3D.new()
		previews.name = "VisualTransitions"
		add_child(previews)
	var group := Node3D.new()
	previews.add_child(group)
	var sources: Dictionary = before.transforms.duplicate(true)
	var destinations: Dictionary = after.transforms.duplicate(true)
	sources[&"@player"] = before.player_transform
	destinations[&"@player"] = after.player_transform
	sources[&"@celestial"] = Transform3D(Basis.IDENTITY, before.celestial_position)
	destinations[&"@celestial"] = Transform3D(Basis.IDENTITY, after.celestial_position)
	var ghosts: Dictionary = {}
	for id in destinations:
		if sources[id] == destinations[id]:
			continue
		var size := Vector3.ONE * (0.8 if id == &"@player" else 1.01)
		if id == &"@celestial":
			size = Vector3.ONE * 0.3
		var ghost := box(size, Color(0.95,0.85,0.55,0.4))
		ghost.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ghost.transform = sources[id]
		group.add_child(ghost)
		ghosts[id] = ghost
	var tween := create_tween()
	tween.tween_method(func(progress: float) -> void:
		for id in ghosts:
			ghosts[id].transform = sources[id].interpolate_with(destinations[id], progress), 0.0, 1.0, duration)
	return {"ok": true, "issues": [], "tween": tween, "preview": group}

func clear_previews() -> void:
	if previews != null:
		for child in previews.get_children():
			child.queue_free()

static func layer_offset(layer: int) -> Vector3:
	return Vector3(-2.4 if layer == 0 else 2.4, 0, 0)

static func pose_basis(orientation: int) -> Basis:
	var columns := Math.columns(orientation)
	return Basis(Vector3(columns[0]), Vector3(columns[1]), Vector3(columns[2]))

static func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat

static func box(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	return node
