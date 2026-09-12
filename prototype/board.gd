extends Node2D

const TILESETS = [preload("res://production/tilesets/surface_tileset.tres"), preload("res://production/tilesets/inner_tileset.tres")]
const PlateScene = preload("res://production/mechanisms/pressure_plate/PressurePlateInner.tscn")
const DoorScene = preload("res://production/mechanisms/door/Door.tscn")
const ExitScene = preload("res://production/mechanisms/exit/ExitGoal.tscn")
var ground: Array[TileMapLayer] = []
var worlds: Array[Node2D] = []
var plate
var door
var goal
var objects: Node2D

func build(state, player: Node2D) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	objects = Node2D.new()
	objects.name = "SortedObjects"
	objects.y_sort_enabled = true
	add_child(objects)
	for w in 2:
		var layer := TileMapLayer.new()
		layer.name = "SurfaceGround" if w == 0 else "InnerGround"
		layer.tile_set = TILESETS[w]
		layer.position = Vector2(-16,-8)
		layer.z_index = -2
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(layer)
		ground.append(layer)
		for cell in state.floors[w]:
			# FLOOR_01 retains its accepted walkable semantics in both worlds.
			layer.set_cell(cell, 0, Vector2i.ZERO)
		var root := Node2D.new()
		root.name = "SurfaceObjects" if w == 0 else "InnerObjects"
		root.y_sort_enabled = true
		objects.add_child(root)
		worlds.append(root)
	plate = place(PlateScene, 1, state.PLATE)
	plate.z_index = -1
	door = place(DoorScene, 0, state.DOOR)
	goal = place(ExitScene, 0, state.EXIT)
	goal.z_index = -1
	objects.add_child(player)
	show_world(0)

func place(scene: PackedScene, world: int, cell: Vector2i):
	var node = scene.instantiate()
	node.position = cell_position(cell)
	worlds[world].add_child(node)
	# Logical arrival owns occupancy. Keep accepted scenes and scripts intact.
	var trigger = node.get_node_or_null("Trigger")
	if trigger:
		trigger.monitoring = false
		trigger.monitorable = false
	return node

func cell_position(cell: Vector2i) -> Vector2:
	return ground[0].position + ground[0].map_to_local(cell)

func show_world(world: int) -> void:
	for w in 2:
		ground[w].visible = w == world
		worlds[w].visible = w == world

func reset_mechanisms() -> void:
	plate.set_active(false)
	door.set_state("closed")
	door.get_node("Shutter/Shape").set_deferred("disabled", false)
	goal.set_state("locked")
