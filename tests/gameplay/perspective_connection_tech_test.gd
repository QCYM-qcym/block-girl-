extends Node2D
const Perspective=preload("res://prototype/perspective/perspective_controller.gd")
const Graph=preload("res://prototype/perspective/connectivity.gd")
const Movement=preload("res://prototype/perspective/grid_movement.gd")
const Cube=preload("res://prototype/perspective/cube_visual.gd")
const Overlay=preload("res://prototype/perspective/debug_overlay.gd")
const ATLAS=[preload("res://production/tilesets/surface/surface_tileset.png"),preload("res://production/tilesets/inner/inner_tileset.png")]
var view=Perspective.new()
var graph=Graph.new()
var mover=Movement.new(graph,view)
var cube=Cube.new()
var overlay=Overlay.new()
var board:=Node2D.new()
var tiles: Dictionary={}
var textures: Array[AtlasTexture]=[]
var marks: Array[Node2D]=[]
var title: Label
var message: Label
var legend: Label
var drag_origin:=Vector2.ZERO
var drag_end:=Vector2.ZERO
var scale_factor:=3
var board_center:=Vector2.ZERO

func _ready() -> void:
	get_window().title="方块少女 · Perspective Connection TECH"
	get_window().size=Vector2i(1280,900)
	get_window().min_size=Vector2i(1000,720)
	get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	RenderingServer.set_default_clear_color(Color("131c22"))
	add_child(board)
	for atlas in ATLAS:
		var texture:=AtlasTexture.new()
		texture.atlas=atlas
		texture.region=Rect2(0,0,64,96)
		texture.filter_clip=true
		textures.append(texture)
	for cell in graph.nodes:
		var tile:=Sprite2D.new()
		tile.texture=textures[0]
		tile.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		tile.z_index=-2
		board.add_child(tile)
		tiles[cell]=tile
	board.add_child(cube)
	cube.bind(mover,view)
	for anchor in [graph.link.a,graph.link.b]:
		var mark:=Polygon2D.new()
		mark.polygon=PackedVector2Array([Vector2(0,-2),Vector2(2,0),Vector2(0,2),Vector2(-2,0)])
		mark.z_index=1
		board.add_child(mark)
		marks.append(mark)
	var hud:=CanvasLayer.new()
	add_child(hud)
	title=make_label(hud,27)
	title.position=Vector2(24,22)
	title.text="PERSPECTIVE CONNECTION   /   技术原型"
	var subtitle:=make_label(hud,16)
	subtitle.position=Vector2(26,68)
	subtitle.text="Move · Shift · Rotate · Solve   |   单面脸：临时测试表现   |   离散 2D 投影摆位"
	hud.add_child(overlay)
	message=make_label(hud,18)
	legend=make_label(hud,16)
	legend.text="按住 WASD / 方向键 连续移动    空格 切换世界    Q / E 切换视角\n左键水平拖动 ≥ 60 px 切换视角    R 重置    F3 Debug    W 永远右上 / D 右下"
	get_viewport().size_changed.connect(layout)
	graph.recalculate(view,mover.world)
	layout()
	refresh()
func make_label(parent: Node,size: int) -> Label:
	var result:=Label.new()
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",Color("dfE7dc"))
	result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result
func layout() -> void:
	var size:=get_viewport_rect().size
	scale_factor=maxi(1,mini(3,floori(minf((size.x-370)/288.0,(size.y-230)/184.0))))
	board.scale=Vector2.ONE*scale_factor
	board_center=Vector2(roundf(355+(size.x-355)/2),roundf(130+(size.y-250)/2))
	overlay.add_theme_font_size_override("font_size",10 if size.y<820 else 14)
	# Font minimum-size invalidation is deferred by Control; shrink afterwards.
	overlay.reset_size.call_deferred()
	message.position=Vector2(24,size.y-105)
	legend.position=Vector2(24,size.y-65)
func _process(delta: float) -> void:
	if view.tick(delta):
		graph.recalculate(view,mover.world)
		mover.message="视角已吸附；连接 %s（%s）。" % ["ACTIVE" if graph.link.active else "INACTIVE",graph.link.reason]
	mover.tick(delta)
	refresh()
func refresh() -> void:
	# Reframe the discrete layout; logical/projected neighbor deltas stay unchanged.
	var center:=projected_center(view.current)
	if view.busy:
		center=center.lerp(projected_center(posmod(view.current+view.rotation_step,4)),view.progress)
	board.position=(board_center-center*scale_factor).round()
	for cell in tiles:
		tiles[cell].position=view.displayed(Vector2(cell),0,graph.nodes[cell]).round()
		tiles[cell].texture=textures[mover.world]
	var at: Vector2=view.displayed(Vector2(mover.cell),0,graph.nodes[mover.cell])
	if mover.moving:
		var dest: Vector2=view.project(Vector2(mover.destination),0,graph.nodes[mover.destination],view.current)
		at=at.lerp(dest,mover.fraction)
	cube.position=at.round()
	cube.queue_redraw()
	for i in 2:
		var anchor=graph.link.a if i==0 else graph.link.b
		marks[i].position=view.displayed(anchor.position(),anchor.elevation,anchor.platform).round()
		marks[i].modulate=Color("90ddb9") if graph.link.active and not view.busy else Color("edaa95")
		marks[i].visible=overlay.visible
	if message:
		message.text=mover.message
		overlay.refresh(mover,view,graph,scale_factor,cube.face_visible,board.position)
func projected_center(index: int) -> Vector2:
	var bounds:=Rect2(view.project(Vector2.ZERO,0,0,index),Vector2.ZERO)
	for cell in graph.nodes:
		bounds=bounds.expand(view.project(Vector2(cell),0,graph.nodes[cell],index))
	return bounds.get_center()
func request_rotation(left: bool) -> void:
	if mover.phase!="idle" or view.busy: return
	if left: view.request_rotate_left()
	else: view.request_rotate_right()
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.echo: return
		var supported: Array=[KEY_W,KEY_D,KEY_S,KEY_A,KEY_UP,KEY_RIGHT,KEY_DOWN,KEY_LEFT,KEY_Q,KEY_E,KEY_SPACE,KEY_R,KEY_F3]
		var key: int=event.physical_keycode if event.physical_keycode in supported else event.keycode
		var directions: Dictionary={KEY_W:0,KEY_UP:0,KEY_D:1,KEY_RIGHT:1,KEY_S:2,KEY_DOWN:2,KEY_A:3,KEY_LEFT:3}
		if directions.has(key):
			if event.pressed: mover.press(key,directions[key])
			else: mover.release(key)
		elif event.pressed:
			match key:
				KEY_Q: request_rotation(true)
				KEY_E: request_rotation(false)
				KEY_SPACE: mover.shift()
				KEY_F3: overlay.visible=not overlay.visible
				KEY_R: reset_fixture()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			if mover.phase=="idle" and view.begin_drag():
				drag_origin=event.position
				drag_end=event.position
		elif view.dragging:
			drag_end=event.position
			view.end_drag(drag_end-drag_origin)
	elif event is InputEventMouseMotion and view.dragging:
		drag_end=event.position
		view.preview_drag(drag_end-drag_origin)
func reset_fixture() -> void:
	view.reset()
	mover.reset()
	graph.recalculate(view,mover.world)
	drag_origin=Vector2.ZERO
	drag_end=Vector2.ZERO
	refresh()
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT and mover:
		mover.clear_held()
		if view.dragging: view.end_drag(Vector2.ZERO)
