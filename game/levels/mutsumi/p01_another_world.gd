extends Node2D
const State=preload("res://game/levels/mutsumi/p01_state.gd")
const Perspective=preload("res://prototype/perspective/perspective_controller.gd")
const Movement=preload("res://prototype/perspective/grid_movement.gd")
const GridInput=preload("res://game/player/grid_input.gd")
const Board=preload("res://game/levels/mutsumi/p01_board.gd")
const Hints=preload("res://game/levels/mutsumi/p01_hints.gd")
const Polish=preload("res://game/polish/p01_polish.gd")
const TutorialView=preload("res://game/polish/p01_tutorial_view.gd")
const CompletionView=preload("res://game/polish/p01_completion_view.gd")
var polish=Polish.new()
var graph=State.new()
var view=Perspective.new()
var mover=Movement.new(graph,view)
var controls=GridInput.new()
var board=Board.new()
var hints=Hints.new()
var world_label: Label
var hint_label: Control
var feedback: Label
var debug: Label
var completion: ColorRect
var completion_label: Label
var footer: Label
var feedback_left:=0.0
func _ready() -> void:
	get_window().title="方块少女 · P-01《另一个世界》 · Polish"
	get_window().size=Vector2i(1280,900)
	get_window().min_size=Vector2i(900,700)
	get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	RenderingServer.set_default_clear_color(Color("172327"))
	graph.bind(mover)
	graph.reset_level()
	add_child(board)
	board.build(graph,mover,view)
	controls.bind(mover,view)
	add_child(controls)
	controls.reset_requested.connect(reset_level)
	controls.debug_requested.connect(func(): debug.visible=not debug.visible)
	controls.shift_rejected.connect(func(): feedback_left=2.5; feedback.text=mover.message)
	var hud:=CanvasLayer.new()
	add_child(hud)
	var title:=label(hud,24)
	title.position=Vector2(32,24)
	title.text="P-01  /  另一个世界"
	world_label=label(hud,16)
	world_label.position=Vector2(33,64)
	hint_label=TutorialView.new()
	hud.add_child(hint_label)
	feedback=label(hud,16)
	feedback.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	footer=label(hud,14)
	footer.text="R  重新开始    ·    M  静音    ·    F3  姿态信息"
	debug=label(hud,14)
	debug.position=Vector2(24,105)
	debug.visible=false
	completion=CompletionView.new()
	hud.add_child(completion)
	completion_label=completion.title
	add_child(polish)
	polish.bind(self)
	get_viewport().size_changed.connect(layout)
	layout()
	refresh()
func label(parent: Node,font_size: int) -> Label:
	var node:=Label.new()
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",Color("d7e3d8"))
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node
func layout() -> void:
	var size:=get_viewport_rect().size
	board.layout(size)
	hint_label.position=Vector2(0,size.y-114)
	hint_label.size=Vector2(size.x,32)
	feedback.position=Vector2(0,size.y-70)
	feedback.size=Vector2(size.x,24)
	footer.position=Vector2(32,size.y-38)
	completion.size=size
	completion_label.size=size
func _process(delta: float) -> void:
	var previous_view: int=view.current
	var rotated:=view.tick(delta)
	if rotated: graph.recalculate(view,mover.world)
	mover.tick(delta)
	hints.update(mover,view,delta,rotated and view.current!=previous_view)
	feedback_left=maxf(0,feedback_left-delta)
	refresh()
	polish.tick(delta)
func refresh() -> void:
	board.refresh()
	footer.text="R  重新开始    ·    M  声音："+("关" if AudioServer.is_bus_mute(0) else "开")+"    ·    F3  姿态信息"
	world_label.text=("表世界  ·  Mutsumi" if mover.world==0 else "里世界  ·  Mortis")+"     /     "+view.VIEW_NAMES[view.current]
	hint_label.text=hints.text
	hint_label.modulate.a=hints.alpha
	feedback.visible=feedback_left>0
	completion.visible=graph.complete
	debug.text="World: %s    View: %s\nGrid: %s    Phase: %s\nOrientation: %s\nLink: %s (%s)\nPlate: %s    Door: %s\nPuzzle: %s    Moves: %s"%[mover.world,view.current,mover.cell,mover.phase,mover.orientation.key(),graph.link.active,graph.link.reason,graph.plate_pressed,graph.door_open,"COMPLETE" if graph.complete else "PLAYING",mover.moves]
	if debug.visible: debug.text+="\n"+board.player.debug_text()
func reset_level() -> void:
	graph.reset_level()
	hints.reset()
	feedback_left=0
	board.reset()
	polish.reset()
	refresh()
