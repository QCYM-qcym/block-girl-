extends RefCounted
## Composition only: the technical scene consumes canonical real Baker output.
const Reader = preload("res://foundation/level/authoring_reader.gd")
const Baker = preload("res://foundation/level/level_baker.gd")
const Authoring = preload("res://tools/foundation/level/runtime_authoring.tscn")

static func bake() -> Dictionary:
	var authoring: Node3D = Authoring.instantiate()
	var read := Reader.read_scene(authoring)
	authoring.free()
	if not read.ok:
		return {"ok":false,"level":null,"issues":read.issues,"validation":null}
	return Baker.bake(read.authoring,{"max_configurations":4096,"max_checks":100000})

static func make_level() -> Dictionary:
	var result := bake()
	return result.level if result.ok else {}
