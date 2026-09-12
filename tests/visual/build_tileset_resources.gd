extends SceneTree

const ROOT = "res://production/tilesets/"
func _initialize() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "tileset_manifest.json"))
	for world in ["surface", "inner"]:
		var ts = TileSet.new()
		ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
		ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
		ts.tile_size = Vector2i(32, 16)
		ts.add_physics_layer()
		ts.set_physics_layer_collision_layer(0, 1)
		var fields = {"logical_id": TYPE_STRING, "walkable": TYPE_BOOL, "elevation": TYPE_INT, "direction": TYPE_STRING, "traversal": TYPE_STRING}
		for key in fields:
			var idx = ts.get_custom_data_layers_count()
			ts.add_custom_data_layer()
			ts.set_custom_data_layer_name(idx, key)
			ts.set_custom_data_layer_type(idx, fields[key])
		for source_id in range(2):
			var atlas = TileSetAtlasSource.new()
			atlas.texture = load(ROOT + world + "/" + world + ("_tileset.png" if source_id == 0 else "_decorations.png"))
			atlas.texture_region_size = Vector2i(64, 96)
			atlas.use_texture_padding = true
			ts.add_source(atlas, source_id)
			for t in manifest.tiles:
				if t.world != world or int(t.source_id) != source_id:
					continue
				var coords = Vector2i(t.atlas_coords[0], t.atlas_coords[1])
				atlas.create_tile(coords)
				var data = atlas.get_tile_data(coords, 0)
				data.texture_origin = Vector2i.ZERO
				data.y_sort_origin = 0
				for key in fields:
					data.set_custom_data(key, int(t[key]) if key == "elevation" else t[key])
				data.set_collision_polygons_count(0, t.collision_polygons.size())
				for p in range(t.collision_polygons.size()):
					var polygon = PackedVector2Array()
					for v in t.collision_polygons[p]:
						polygon.append(Vector2(v[0], v[1]))
					data.set_collision_polygon_points(0, p, polygon)
		var error = ResourceSaver.save(ts, ROOT + world + "_tileset.tres")
		if error != OK:
			push_error("TileSet save failed " + str(error))
			quit(2)
			return
		print("BUILT ", world, " ", ts.get_source_count(), " sources")
	quit()
