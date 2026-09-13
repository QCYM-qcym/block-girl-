extends Node2D
const Graph=preload("res://prototype/perspective/connectivity.gd")
const View=preload("res://prototype/perspective/perspective_controller.gd")
const Movement=preload("res://prototype/perspective/grid_movement.gd")
const Controls=preload("res://game/player/grid_input.gd")
const Cube=preload("res://game/player/cube_visual_presenter.gd")
var graph=Graph.new()
var view=View.new()
var mover=Movement.new(graph,view)
var controls=Controls.new()
var cube=Cube.new()
var debug: Label
var skin: Label
var axis_label: Label
func _ready() -> void:
	get_window().title="Cube Orientation Visual Test · 单面滚动验收"
	get_window().size=Vector2i(1200,820)
	get_window().min_size=Vector2i(1000,720)
	get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	RenderingServer.set_default_clear_color(Color("172327"))
	# Test-only support grid; no change to P01 or the accepted tech fixture.
	graph.nodes.clear()
	for x in range(-12,13):
		for z in range(-12,13): graph.nodes[Vector2i(x,z)]=0
	graph.link.enabled=false
	add_child(cube); cube.bind(mover,view); cube.scale=Vector2.ONE*10
	controls.bind(mover,view); add_child(controls)
	controls.reset_requested.connect(reset_fixture)
	controls.debug_requested.connect(func(): debug.visible=not debug.visible)
	var title:=make_label(24,Vector2(26,22))
	title.text="CUBE ORIENTATION / 单面滚动验收"
	skin=make_label(17,Vector2(26,66))
	debug=make_label(15,Vector2(26,130))
	axis_label=make_label(16,Vector2(26,590))
	axis_label.text="金色 X 只在一个物理面；其它面无标记。\n临时技术表现 · 正式角色 Sprite 待重制"
	var legend:=make_label(17,Vector2(26,685))
	legend.text="按住 WASD 连续滚动   Space 换肤   Q/E 或鼠标水平拖动转视角\nR 重置   F3 状态   大方块固定屏幕位置，便于比较连续姿态"
	get_viewport().size_changed.connect(layout)
	reset_fixture(); layout()
func make_label(size: int,at: Vector2) -> Label:
	var label:=Label.new(); label.position=at
	label.add_theme_font_size_override("font_size",size)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(label); return label
func layout() -> void:
	cube.position=Vector2(get_viewport_rect().size.x*0.73,410).round()
func reset_fixture() -> void:
	view.reset(); mover.reset(); graph.recalculate(view,0)
func _process(delta: float) -> void:
	if view.tick(delta): graph.recalculate(view,mover.world)
	mover.tick(delta)
	cube.refresh()
	debug.text=cube.debug_text()+"\nGrid: %s    Moves: %s"%[mover.cell,mover.moves]
	skin.text=("Surface / Mutsumi" if mover.world==0 else "Inner / Mortis")+"   ·   "+view.VIEW_NAMES[view.current]
