extends Node2D
const ATLAS=[preload("res://production/tilesets/surface/surface_tileset.png"),preload("res://production/tilesets/inner/inner_tileset.png")]
const PlateScene=preload("res://production/mechanisms/pressure_plate/PressurePlate.tscn")
const DoorScene=preload("res://production/mechanisms/door/Door.tscn")
const ExitScene=preload("res://production/mechanisms/exit/ExitGoal.tscn")
const Player=preload("res://game/player/orientation_sprite_presenter.gd")
var graph
var mover
var view
var tiles: Dictionary={}
var textures: Array[AtlasTexture]=[]
var player=Player.new()
var plate
var door
var goal
var previous_door:=false
var previous_complete:=false
var scale_factor:=3
var center:=Vector2.ZERO
func build(state,movement,perspective) -> void:
	graph=state; mover=movement; view=perspective
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	y_sort_enabled=true
	for atlas in ATLAS:
		var texture:=AtlasTexture.new()
		texture.atlas=atlas
		texture.region=Rect2(0,0,64,96)
		texture.filter_clip=true
		textures.append(texture)
	for cell in graph.nodes:
		var tile:=Sprite2D.new()
		tile.texture=textures[0]
		tile.z_index=-2
		add_child(tile)
		tiles[cell]=tile
	plate=place(PlateScene)
	plate.z_index=-1
	door=place(DoorScene)
	goal=place(ExitScene)
	goal.z_index=-1
	add_child(player)
	player.bind(mover,view)
	reset()
func place(scene: PackedScene):
	var item=scene.instantiate()
	add_child(item)
	var trigger=item.get_node_or_null("Trigger")
	if trigger:
		trigger.monitoring=false
		trigger.monitorable=false
	# Logical edges own collision; disable asset physics so it cannot disagree
	# with occupancy timing. Production standalone scenes remain unchanged.
	for child in item.get_children():
		if child is CollisionObject2D:
			child.collision_layer=0
			child.collision_mask=0
	return item
func reset() -> void:
	previous_door=false; previous_complete=false
	plate.set_active(false)
	door.set_state("closed")
	goal.set_state("ready")
func layout(size: Vector2) -> void:
	# Fit every view with the same integer scale; leave space for the HUD.
	var largest:=Vector2.ZERO
	for v in 4:
		var bounds:=bounds_for(v)
		largest.x=maxf(largest.x,bounds.size.x+32)
		largest.y=maxf(largest.y,bounds.size.y+64)
	scale_factor=clampi(floori(minf((size.x-96)/largest.x,(size.y-220)/largest.y)),1,4)
	scale=Vector2.ONE*scale_factor
	center=Vector2(size.x/2,(size.y+40)/2).round()
func bounds_for(index: int) -> Rect2:
	var bounds:=Rect2(view.project(Vector2(graph.START),0,0,index),Vector2.ZERO)
	for cell in graph.nodes: bounds=bounds.expand(view.project(Vector2(cell),0,graph.nodes[cell],index))
	return bounds
func projected(cell: Vector2,platform: int) -> Vector2:
	return view.displayed(cell,0,platform).round()
func refresh() -> void:
	var framing:=bounds_for(view.current).get_center()
	if view.busy: framing=framing.lerp(bounds_for(posmod(view.current+view.rotation_step,4)).get_center(),view.progress)
	position=(center-framing*scale_factor).round()
	for cell in tiles:
		tiles[cell].position=projected(Vector2(cell),graph.nodes[cell])
		tiles[cell].texture=textures[mover.world]
		tiles[cell].visible=graph.can_stand(cell,mover.world)
	var at: Vector2=view.displayed(Vector2(mover.cell),0,graph.nodes[mover.cell])
	if mover.moving: at=at.lerp(view.project(Vector2(mover.destination),0,graph.nodes[mover.destination],view.current),mover.fraction)
	player.position=at.round()
	player.refresh()
	plate.position=projected(Vector2(graph.PLATE),1)
	door.position=projected(Vector2(11.5,0),1)
	goal.position=projected(Vector2(graph.EXIT),1)
	# NE/SW production gate is mirrored for the other diagonal screen axis.
	door.scale.x=1 if view.current in [1,3] else -1
	for item in [plate,door,goal]:
		item.modulate=Color.WHITE if mover.world==0 else Color(0.45,0.45,0.65,0.55)
	var plate_state: String="pressed" if graph.plate_pressed else "idle"
	if plate.state!=plate_state: plate.set_state(plate_state)
	if graph.door_open!=previous_door:
		previous_door=graph.door_open
		door.set_open(graph.door_open)
	# Committing occupancy can immediately start another held roll. Keep the
	# accepted gate fully open throughout the already-authorized crossing.
	if mover.moving and mover.cell==graph.PLATE and mover.destination==graph.BEYOND_GATE and door.state!="open":
		door.set_state("open")
	if graph.complete and not previous_complete:
		goal.set_state("active")
		goal.complete_goal()
		previous_complete=true
	elif not graph.complete:
		var ready: String="ready" if mover.world==0 else "locked"
		if goal.state!=ready: goal.set_state(ready)
