extends SceneTree
## Command-line boundary for producing one validated, canonical LevelDefinition.
const AuthoringReader = preload("res://foundation/level/authoring_reader.gd")
const Baker = preload("res://foundation/level/level_baker.gd")
const Codec = preload("res://foundation/level/level_codec.gd")
const BUDGET := {"max_configurations": 4096, "max_checks": 100000}


func _initialize() -> void:
	var arguments := _parse_arguments(OS.get_cmdline_user_args())
	if not arguments.ok:
		_fail(arguments.message)
		return
	var scene_path: String = arguments.scene
	var output_path := _resolve_output_path(arguments.output)
	if output_path.is_empty():
		_fail("--output must be an explicit res:// path inside this E: project or an absolute E: path.")
		return
	if FileAccess.file_exists(output_path) or DirAccess.dir_exists_absolute(output_path):
		_fail("Refusing to overwrite existing output: " + output_path)
		return
	if not _valid_scene_path(scene_path):
		_fail("--scene must name an existing res:// PackedScene inside this project.")
		return
	var packed: Resource = ResourceLoader.load(scene_path, "PackedScene")
	if not packed is PackedScene:
		_fail("Could not load PackedScene: " + scene_path)
		return
	var instance: Node = packed.instantiate()
	if not instance is Node3D:
		instance.free()
		_fail("Authoring scene root must be Node3D: " + scene_path)
		return
	var root := instance as Node3D
	var read: Dictionary = AuthoringReader.read_scene(root)
	root.free()
	if not read.ok:
		_fail("Authoring read failed: " + str(read.issues))
		return
	var baked: Dictionary = Baker.bake(read.authoring, BUDGET)
	if not baked.ok:
		_fail("Bake failed: " + str(baked.issues))
		return
	var encoded: Dictionary = Codec.encode(baked.level)
	if not encoded.ok:
		_fail("Canonical encode failed: " + str(encoded.issues))
		return
	if encoded.text.ends_with("\n"):
		_fail("Canonical encoder returned a trailing newline.")
		return
	var write_error := _write_new_file(output_path, encoded.text.to_utf8_buffer())
	if not write_error.is_empty():
		_fail(write_error)
		return
	print("FOUNDATION_LEVEL_BAKE_PASS output=%s content_hash=%s" % [output_path, baked.level.content_hash])
	quit(0)


func _parse_arguments(raw: PackedStringArray) -> Dictionary:
	var parsed := {"ok": false, "scene": "", "output": "", "message": ""}
	for argument in raw:
		var separator := argument.find("=")
		if separator <= 2 or separator == argument.length() - 1:
			parsed.message = "Malformed argument: " + argument
			return parsed
		var key := argument.substr(0, separator)
		var value := argument.substr(separator + 1)
		if key not in ["--scene", "--output"]:
			parsed.message = "Unknown argument: " + key
			return parsed
		var field := key.substr(2)
		if not parsed[field].is_empty():
			parsed.message = "Duplicate argument: " + key
			return parsed
		parsed[field] = value
	if parsed.scene.is_empty() or parsed.output.is_empty() or raw.size() != 2:
		parsed.message = "Exactly --scene=<res:// PackedScene> and --output=<explicit E: path> are required."
		return parsed
	parsed.ok = true
	return parsed


func _valid_scene_path(path: String) -> bool:
	if not path.begins_with("res://") or path.contains("\\"):
		return false
	var absolute := ProjectSettings.globalize_path(path).simplify_path().replace("\\", "/")
	var project := ProjectSettings.globalize_path("res://").simplify_path().replace("\\", "/").trim_suffix("/")
	if not absolute.begins_with(project + "/"):
		return false
	return ResourceLoader.exists(path, "PackedScene")


func _resolve_output_path(path: String) -> String:
	if path.is_empty():
		return ""
	var absolute := ""
	if path.begins_with("res://"):
		if path.contains("\\"):
			return ""
		absolute = ProjectSettings.globalize_path(path).simplify_path().replace("\\", "/")
		var project := ProjectSettings.globalize_path("res://").simplify_path().replace("\\", "/").trim_suffix("/")
		if not absolute.begins_with(project + "/"):
			return ""
	elif path.is_absolute_path():
		absolute = path.simplify_path().replace("\\", "/")
	else:
		return ""
	if not absolute.to_lower().begins_with("e:/") or absolute.ends_with("/"):
		return ""
	return absolute


func _write_new_file(output_path: String, bytes: PackedByteArray) -> String:
	var parent := output_path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(parent)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return "Could not create output directory (error %d): %s" % [directory_error, parent]
	if FileAccess.file_exists(output_path) or DirAccess.dir_exists_absolute(output_path):
		return "Refusing to overwrite existing output: " + output_path
	var temporary_path := output_path + ".tmp-%d" % OS.get_process_id()
	if FileAccess.file_exists(temporary_path) or DirAccess.dir_exists_absolute(temporary_path):
		return "Temporary output path already exists: " + temporary_path
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return "Could not open temporary output (error %d): %s" % [FileAccess.get_open_error(), temporary_path]
	file.store_buffer(bytes)
	file.flush()
	var file_error := file.get_error()
	file = null
	if file_error != OK or FileAccess.get_file_as_bytes(temporary_path) != bytes:
		DirAccess.remove_absolute(temporary_path)
		return "Could not verify complete temporary output (error %d)." % file_error
	if FileAccess.file_exists(output_path) or DirAccess.dir_exists_absolute(output_path):
		DirAccess.remove_absolute(temporary_path)
		return "Refusing to overwrite output created during bake: " + output_path
	var publish_error := _publish_without_overwrite(temporary_path, output_path)
	if not publish_error.is_empty():
		DirAccess.remove_absolute(temporary_path)
		return publish_error
	return ""


static func _publish_without_overwrite(temporary_path: String, output_path: String) -> String:
	# This CLI is E:/Windows-specific. System.IO.File.Move(source, destination)
	# is the target platform's atomic fail-if-destination-exists primitive.
	if OS.get_name() != "Windows":
		return "Atomic no-overwrite publication is supported only on Windows."
	var source_base64 := Marshalls.raw_to_base64(temporary_path.to_utf8_buffer())
	var target_base64 := Marshalls.raw_to_base64(output_path.to_utf8_buffer())
	var command := ("$source=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('%s'));" % source_base64
		+ "$target=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('%s'));" % target_base64
		+ "try {[IO.File]::Move($source,$target);exit 0}"
		+ "catch [IO.IOException] {[Console]::Error.Write($_.Exception.Message);exit 17}"
		+ "catch {[Console]::Error.Write($_.Exception.Message);exit 18}")
	var encoded_command := Marshalls.raw_to_base64(command.to_utf16_buffer())
	var process_output: Array = []
	var exit_code := OS.execute("powershell.exe", PackedStringArray([
		"-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden",
		"-EncodedCommand", encoded_command,
	]), process_output, true, false)
	if exit_code == 0:
		return ""
	return "Could not publish output without overwriting (exit %d): %s" % [exit_code, "".join(process_output).strip_edges()]


func _fail(message: String) -> void:
	printerr("FOUNDATION_LEVEL_BAKE_ERROR " + message)
	quit(1)
