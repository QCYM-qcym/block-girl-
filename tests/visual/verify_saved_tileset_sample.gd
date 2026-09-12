extends SceneTree
func _initialize() -> void:
	var sample = load("res://tests/visual/tileset_paired_sample.tscn").instantiate()
	var failures = []
	var counts = []
	for layer_name in ["Ground","Structures","ElevatedBridge","ElevatedWall","Decorations"]:
		var a = sample.get_node("Surface/"+layer_name) as TileMapLayer
		var b = sample.get_node("Inner/"+layer_name) as TileMapLayer
		if a.get_used_cells() != b.get_used_cells(): failures.append(layer_name+" cells")
		if a.position != b.position or a.z_index != b.z_index: failures.append(layer_name+" transform")
		for cell in a.get_used_cells():
			if a.get_cell_tile_data(cell).get_custom_data("logical_id") != b.get_cell_tile_data(cell).get_custom_data("logical_id"): failures.append(layer_name+" logical id")
		counts.append({"layer":layer_name,"cells_per_world":a.get_used_cells().size()})
	var result = {"status":"PASS" if failures.is_empty() else "FAIL","tile_map_layers":10,"counts":counts,"failures":failures}
	var file = FileAccess.open("res://tests/visual/tileset_evidence/saved_sample_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print(JSON.stringify(result))
	sample.free()
	quit(0 if failures.is_empty() else 2)
