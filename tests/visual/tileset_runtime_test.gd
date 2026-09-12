extends Node2D
## Asset-only fixtures: real TileMapLayer rendering, fixed test poses, no controller.
const ROOT = "res://production/tilesets/"
const WORLDS = ["surface", "inner"]
const BG = Color("24313a")
var manifest: Dictionary
var sets: Array[TileSet] = []
var lookup: Array = [{}, {}]
var stage: Node2D
var output = ""
var automatic = false
var report: Dictionary = {"failures": [], "captures": [], "resource_checks": [], "map_positions": []}

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--auto": automatic = true
		if arg.begins_with("--evidence-dir="): output = arg.trim_prefix("--evidence-dir=")
	if output.is_empty(): output = ProjectSettings.globalize_path("res://tests/visual/tileset_evidence/manual")
	DirAccess.make_dir_recursive_absolute(output)
	get_window().title = "Tileset Runtime Validation — Surface / Inner"
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size = Vector2i.ZERO
	get_window().unresizable = true
	get_window().size = Vector2i(1280, 960)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bg = ColorRect.new()
	bg.color = BG
	bg.size = Vector2(1280, 960)
	bg.z_index = -100
	add_child(bg)
	manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "tileset_manifest.json"))
	for w in range(2):
		sets.append(load(ROOT + WORLDS[w] + "_tileset.tres"))
		for t in manifest.tiles:
			if t.world == WORLDS[w]: lookup[w][t.logical_id] = t
	report.engine = Engine.get_version_info()
	report.display_server = DisplayServer.get_name()
	report.renderer = RenderingServer.get_current_rendering_method()
	report.driver = RenderingServer.get_current_rendering_driver_name()
	report.gpu = RenderingServer.get_video_adapter_name()
	report.window = [get_window().size.x, get_window().size.y]
	report.filter = texture_filter
	validate_resources()
	if automatic: run_suite.call_deferred()
	else: demo()

func require(ok: bool, message: String) -> void:
	if not ok: report.failures.append(message)

func validate_resources() -> void:
	for w in range(2):
		var ts = sets[w]
		require(ts.tile_size == Vector2i(32,16), "tile size")
		require(ts.tile_shape == TileSet.TILE_SHAPE_ISOMETRIC, "tile shape")
		require(ts.tile_layout == TileSet.TILE_LAYOUT_DIAMOND_DOWN, "tile layout")
		for id in lookup[w]:
			var t = lookup[w][id]
			var atlas = ts.get_source(int(t.source_id)) as TileSetAtlasSource
			var coords = Vector2i(t.atlas_coords[0], t.atlas_coords[1])
			var data = atlas.get_tile_data(coords,0)
			require(atlas.get_tile_texture_region(coords).size == Vector2i(64,96), "region " + id)
			require(data.texture_origin == Vector2i.ZERO, "origin " + id)
			require(data.get_collision_polygons_count(0) == t.collision_polygons.size(), "collision count " + id)
			for p in range(t.collision_polygons.size()):
				var actual = data.get_collision_polygon_points(0,p)
				for j in range(actual.size()): require(actual[j] == Vector2(t.collision_polygons[p][j][0],t.collision_polygons[p][j][1]), "collision vertex " + id)
			for key in ["logical_id","walkable","elevation","direction","traversal"]: require(data.get_custom_data(key) == t[key], "custom data " + id + " " + key)
			var paired = lookup[1-w][id]
			for key in ["logical_footprint","diamond","pivot","elevation","direction","walkable","collision_required","collision_polygons","traversal"]: require(t[key] == paired[key], "pair parity " + id + " " + key)
		for source_id in range(2):
			var a = ts.get_source(source_id) as TileSetAtlasSource
			var config = ConfigFile.new()
			config.load(a.texture.resource_path + ".import")
			var item = {"world": WORLDS[w], "path": a.texture.resource_path, "tiles": a.get_tiles_count(), "compression": config.get_value("params","compress/mode"), "mipmaps": config.get_value("params","mipmaps/generate"), "loaded_mipmaps": a.texture.get_image().has_mipmaps()}
			require(item.compression == 0 and item.mipmaps == false and item.loaded_mipmaps == false, "PNG import")
			report.resource_checks.append(item)

func clear_stage(title: String) -> void:
	if is_instance_valid(stage):
		remove_child(stage)
		stage.queue_free()
	stage = Node2D.new()
	add_child(stage)
	label(title, Vector2(32,20), 25)

func label(text: String, at: Vector2, size: int = 18) -> void:
	var l = Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size", size)
	stage.add_child(l)

func group(at: Vector2, factor: int) -> Node2D:
	var node = Node2D.new()
	node.position = at
	node.scale = Vector2.ONE * factor
	node.y_sort_enabled = true
	stage.add_child(node)
	return node

func layer(parent: Node2D, w: int, depth: int = 0) -> TileMapLayer:
	var l = TileMapLayer.new()
	l.name = "Tiles_" + WORLDS[w]
	l.tile_set = sets[w]
	l.position = -l.map_to_local(Vector2i.ZERO)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l.y_sort_enabled = true
	l.y_sort_origin = 0
	l.z_index = depth
	parent.add_child(l)
	return l

func put(l: TileMapLayer, w: int, id: String, cell: Vector2i) -> void:
	var t = lookup[w][id]
	l.set_cell(cell, int(t.source_id), Vector2i(t.atlas_coords[0],t.atlas_coords[1]))

func character(parent: Node2D, w: int, at: Vector2, depth: int = 0) -> AnimatedSprite2D:
	var body = AnimatedSprite2D.new()
	body.name = "Mutsumi" if w == 0 else "Mortis"
	body.sprite_frames = load("res://production/sprites/" + ("mutsumi" if w == 0 else "mortis") + "_sprite_frames.tres")
	body.animation = "idle"
	body.frame = 0
	body.offset = Vector2(0,-9)
	body.position = at
	body.z_index = depth
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(body)
	return body

func demo() -> void:
	clear_stage("PAIRED ENVIRONMENT  /  SAME LOGICAL LAYOUT  /  3x")
	for w in range(2):
		label(WORLDS[w].to_upper(), Vector2(180+w*640,100),24)
		var g = group(Vector2(240+w*640,300),3)
		g.name = WORLDS[w].capitalize()
		var ground = layer(g,w,-2)
		ground.name = "Ground"
		for x in range(3):
			for y in range(2,4): put(ground,w,"FLOOR_01",Vector2i(x,y))
		var structures = layer(g,w)
		structures.name = "Structures"
		for x in range(3): put(structures,w,"PLATFORM_RAISED",Vector2i(x,0))
		put(structures,w,"STAIR_MULTI_NE",Vector2i(1,1))
		put(structures,w,"PLATFORM_FLOATING",Vector2i(5,0))
		put(structures,w,"PILLAR",Vector2i(-1,1))
		put(structures,w,"BRIDGE_BROKEN_SE",Vector2i(4,3))
		var bridge = layer(g,w,-1)
		bridge.name = "ElevatedBridge"
		bridge.position.y -= 8
		put(bridge,w,"BRIDGE_SE",Vector2i(3,0))
		put(bridge,w,"BRIDGE_SE",Vector2i(4,0))
		var wall = layer(g,w)
		wall.name = "ElevatedWall"
		wall.position.y -= 8
		put(wall,w,"WALL_TALL_NE",Vector2i(0,0))
		var decoration = layer(g,w,1)
		decoration.name = "Decorations"
		put(decoration,w,"WHITE_FLOWER",Vector2i(2,3))
		put(decoration,w,"GRASS_TUFT",Vector2i(0,3))
		character(g,w,ground.position + ground.map_to_local(Vector2i(1,3)))
	label("6 floors / raised landing / stairs / continuous bridge / floating platform / wall / pillar / separate gap sample",Vector2(32,650),18)
	label("Character feet: tile center. Test placement only. No level or puzzle logic.",Vector2(32,686),18)
	label("Manual: D paired scene | 1-4 pixel scales | F floor joins | W wall corner | T stair join | O depth poses",Vector2(32,908),17)

func galleries(factor: int, start: int = 0) -> Array:
	clear_stage("NATIVE PIXEL REGIONS / " + str(factor) + "x / page " + str(start/4))
	var ids = lookup[0].keys()
	var placement = []
	for w in range(2):
		for slot in range(4):
			var index = start + slot
			if index >= ids.size(): continue
			var id = ids[index]
			var pos = Vector2(160+slot*320,270+w*440)
			var g = group(pos,factor)
			var l = layer(g,w)
			put(l,w,id,Vector2i.ZERO)
			label(WORLDS[w]+" / "+id,Vector2(pos.x-145,pos.y-215),14)
			placement.append({"world":w,"logical_id":id,"scale":factor,"anchor":[pos.x,pos.y],"cell_center":[l.map_to_local(Vector2i.ZERO).x,l.map_to_local(Vector2i.ZERO).y]})
	return placement

func seams(kind: String, factor: int) -> Array:
	clear_stage("JOIN FIXTURE / " + kind + " / " + str(factor) + "x")
	var placement = []
	for w in range(2):
		var pos = Vector2(180+w*640,330)
		var g = group(pos,factor)
		var l = layer(g,w)
		var items = []
		if kind == "floor":
			for x in range(5):
				put(l,w,"FLOOR_01",Vector2i(x,0))
				items.append({"id":"FLOOR_01","cell":[x,0]})
		elif kind == "stair":
			put(l,w,"PLATFORM_RAISED",Vector2i(0,-1))
			put(l,w,"STAIR_MULTI_NE",Vector2i.ZERO)
			put(l,w,"FLOOR_01",Vector2i(0,1))
			items = [{"id":"PLATFORM_RAISED","cell":[0,-1]},{"id":"STAIR_MULTI_NE","cell":[0,0]},{"id":"FLOOR_01","cell":[0,1]}]
		else:
			put(l,w,"WALL_TALL_NE",Vector2i.ZERO)
			put(l,w,"WALL_TALL_NE",Vector2i(1,0))
			var other = layer(g,w)
			put(other,w,"WALL_TALL_NW",Vector2i.ZERO)
			put(other,w,"WALL_TALL_NW",Vector2i(0,1))
			items = [{"id":"WALL_TALL_NE","cell":[0,0]},{"id":"WALL_TALL_NE","cell":[1,0]},{"id":"WALL_TALL_NW","cell":[0,0]},{"id":"WALL_TALL_NW","cell":[0,1]}]
		for cell in [Vector2i.ZERO,Vector2i(1,0),Vector2i(0,1)]:
			var actual = l.map_to_local(cell)
			report.map_positions.append({"cell":[cell.x,cell.y],"local":[actual.x,actual.y]})
		placement.append({"world":w,"scale":factor,"anchor":[pos.x,pos.y],"items":items})
	return placement

func depth_fixture(pose: String, mode: String) -> Array:
	clear_stage("DEPTH / " + pose + " / " + mode + " / 4x")
	var data = []
	for w in range(2):
		var pos = Vector2(320+w*640,390)
		var g = group(pos,4)
		var l = layer(g,w)
		var tile = "WALL_TALL_SW" if pose.begins_with("wall") else "PLATFORM_RAISED"
		var at = Vector2(0,-10) if pose.ends_with("behind") else Vector2(0,10)
		var z = 0
		if pose == "stair":
			tile = "STAIR_MULTI_NE"
			at = Vector2(0,-4)
			z = 1
		if pose == "bridge":
			tile = "BRIDGE_NE"
			at = Vector2.ZERO
			z = 1
		if pose == "platform_top":
			at = Vector2(0,-8)
			z = 1
		if mode != "character_only": put(l,w,tile,Vector2i.ZERO)
		if mode != "tile_only": character(g,w,at,z)
		data.append({"world":w,"anchor":[pos.x,pos.y],"tile":tile,"feet":[at.x,at.y],"character_z":z,"expected_front":not pose.ends_with("behind")})
	return data

func capture(file: String, kind: String, placements: Array) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	require(img.save_png(output + "/" + file + ".png") == OK,"capture " + file)
	report.captures.append({"file":file+".png","kind":kind,"placements":placements})

func run_suite() -> void:
	await collision_fixture()
	demo()
	stage.name = "TilesetPairedSample"
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_sample_owner(stage)
	var packed = PackedScene.new()
	require(packed.pack(stage) == OK, "pack editable sample")
	require(ResourceSaver.save(packed,"res://tests/visual/tileset_paired_sample.tscn") == OK,"save editable sample")
	await capture("paired_environment","demo",[])
	for factor in range(1,5):
		# Every tile rendered at every requested integer scale.
		for start in range(0,lookup[0].size(),4):
			var p = galleries(factor,start)
			await capture("gallery_"+str(factor)+"x_"+str(start),"gallery",p)
		for kind in ["floor","stair","wall"]:
			var p = seams(kind,factor)
			await capture("seam_"+kind+"_"+str(factor)+"x","seam_"+kind,p)
	for pose in ["wall_front","wall_behind","platform_front","platform_behind","platform_top","stair","bridge"]:
		for mode in ["tile_only","character_only","combined"]:
			var p = depth_fixture(pose,mode)
			await capture("depth_"+pose+"_"+mode,"depth",p)
	demo()
	await capture("paired_environment_final","demo",[])
	report.status = "ENGINE_CHECKS_PASS" if report.failures.is_empty() else "ENGINE_CHECKS_FAIL"
	var file = FileAccess.open(output + "/engine_runtime_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print(report.status, " captures=", report.captures.size(), " failures=",report.failures)
	get_tree().quit(0 if report.failures.is_empty() else 2)

func set_sample_owner(node: Node) -> void:
	for child in node.get_children():
		child.owner = stage
		set_sample_owner(child)

func collision_fixture() -> void:
	report.physics_queries = []
	for id in ["FLOOR_01","BRIDGE_BROKEN_NE","WALL_LOW_NE","PILLAR","ARCH_NE"]:
		clear_stage("BASIC COLLISION QUERY / " + id)
		for w in range(2):
			var g = group(Vector2(320+w*640,390),1)
			var l = layer(g,w)
			put(l,w,id,Vector2i.ZERO)
			l.update_internals()
		await get_tree().physics_frame
		await get_tree().physics_frame
		for w in range(2):
			var samples = [{"point":Vector2.ZERO,"hit":id == "PILLAR"}]
			if id == "WALL_LOW_NE": samples = [{"point":Vector2(6,-3),"hit":true}]
			if id == "ARCH_NE": samples.append({"point":Vector2(-6,-3),"hit":true})
			for sample in samples:
				var query = PhysicsPointQueryParameters2D.new()
				query.position = Vector2(320+w*640,390) + sample.point
				query.collision_mask = 1
				var hits = get_world_2d().direct_space_state.intersect_point(query)
				var passed = (hits.size() > 0) == sample.hit
				require(passed,"physics query " + id + " " + str(w))
				report.physics_queries.append({"tile":id,"world":w,"point":str(sample.point),"expected_hit":sample.hit,"hits":hits.size(),"pass":passed})

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or automatic: return
	if event.keycode == KEY_D: demo()
	if event.keycode >= KEY_1 and event.keycode <= KEY_4: galleries(event.keycode-KEY_0)
	if event.keycode == KEY_F: seams("floor",4)
	if event.keycode == KEY_W: seams("wall",4)
	if event.keycode == KEY_T: seams("stair",4)
	if event.keycode == KEY_O: depth_fixture("wall_behind","combined")
