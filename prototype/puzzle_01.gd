extends Node2D

const State = preload("res://prototype/puzzle_state.gd")
const Board = preload("res://prototype/board.gd")
const PlayerScene = preload("res://prototype/player.tscn")
var state = State.new()
var board = Board.new()
var player
var title_label: Label
var status_label: Label
var message_label: Label
var controls_label: Label
var complete_label: Label
var help_level := 0

func _ready() -> void:
	get_window().title = "方块少女 · P-01 另一个世界"
	get_window().min_size = Vector2i(800,600)
	get_window().size = Vector2i(1280,800)
	# Scene-local sizing: no global resolution or renderer changes.
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	RenderingServer.set_default_clear_color(Color("131c22"))
	add_child(board)
	player = PlayerScene.instantiate()
	board.build(state, player)
	player.position = board.cell_position(state.cell)
	player.move_requested.connect(_move)
	player.switch_requested.connect(_switch)
	player.reset_requested.connect(reset_level)
	player.hint_requested.connect(_hint)
	player.action_finished.connect(_action_finished)
	board.door.passage_changed.connect(_door_changed)
	board.goal.completed.connect(_completed)
	_build_hud()
	get_viewport().size_changed.connect(_layout)
	_layout()
	refresh()
	feedback("表世界的路断了。空格切换世界，寻找通往出口的办法。")

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "MinimalHUD"
	add_child(hud)
	title_label = label(hud, 29, Color("e5e7dc"))
	status_label = label(hud, 18, Color("a7bbb6"))
	message_label = label(hud, 19, Color("d9decb"))
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_label = label(hud, 16, Color("92a4a9"))
	controls_label.text = "W / ↑ 右上    D / → 右下    S / ↓ 左下    A / ← 左上\n空格 切换世界     R 随时重置     H 提示     每按一次移动一格"
	complete_label = label(hud, 30, Color("e2efd9"))
	complete_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	complete_label.text = "PUZZLE COMPLETE\n你在另一个世界找到了答案。\n按 R 再玩一次"
	complete_label.visible = false

func label(parent: Node, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	parent.add_child(result)
	return result

func _layout() -> void:
	var size := get_viewport_rect().size
	# Native board bounds: x -160..176, y -8..152. Keep integer pixels.
	var factor := maxi(1, mini(4, floori(minf((size.x-100)/336.0, (size.y-280)/168.0))))
	board.scale = Vector2.ONE * factor
	board.position = Vector2(roundf(size.x/2.0-8*factor), roundf(160+(size.y-280-168*factor)/2.0))
	title_label.position = Vector2(32,24)
	status_label.position = Vector2(34,70)
	controls_label.position = Vector2(34,size.y-68)
	message_label.position = Vector2(34,size.y-120)
	message_label.size = Vector2(size.x-68,48)
	complete_label.position = Vector2(32,112)
	complete_label.size.x = size.x-64

func _move(direction: Vector2i) -> void:
	if state.phase != "idle": return
	if state.begin_move(direction):
		player.roll(board.cell_position(state.destination), direction)
	else:
		feedback(state.rejection, true)

func _switch() -> void:
	if state.phase != "idle": return
	if state.begin_switch():
		player.play_action("switching", "world_switch")
		feedback("正在切换……坐标保持不变。")
	else:
		feedback(state.rejection, true)

func _action_finished(action: String) -> void:
	match action:
		"moving": state.finish_move()
		"switching":
			state.finish_switch()
			player.set_world(state.world)
			board.show_world(state.world)
			feedback("里世界显现了新的道路。寻找压力板。" if state.world == 1 else "回到表世界。沿门后的通道抵达出口。")
		"pressing":
			state.activate_plate()
			board.plate.set_active(true)
			board.door.set_open(true)
			feedback("压力板已点亮！门正在开启；离开踏板后仍保持有效，R 可重置。")
	if state.phase == "pressing":
		board.plate.set_state("pressed")
		player.play_action("pressing", "interaction")
		feedback("踩下压力板……")
	elif state.phase == "completing":
		board.goal.set_state("active")
		board.goal.complete_goal()
		player.play_action("celebrating", "puzzle_complete")
	refresh()

func _door_changed(open: bool) -> void:
	if open and state.plate_latched:
		state.mark_door_open()
		board.goal.set_ready(true)
		refresh()

func _completed() -> void:
	state.finish_puzzle()
	refresh()
	feedback("谜题完成。按 R 可从起点重新开始。")

func reset_level() -> void:
	state.reset()
	player.reset_player(board.cell_position(state.cell))
	board.reset_mechanisms()
	board.show_world(0)
	help_level = 0
	refresh()
	feedback("已重置：回到表世界起点，压力板与门恢复初始状态。")

func refresh() -> void:
	title_label.text = "P—01   另一个世界   /   " + ("SURFACE · 若叶睦" if state.world == 0 else "INNER · Mortis")
	var door_text: String = "已开启" if state.door_open else ("开启中" if state.plate_latched else "关闭")
	status_label.text = "压力板：%s     门：%s     步数：%d     切换：%d" % ["已点亮 · 保持" if state.plate_latched else "未触发", door_text, state.moves, state.switches]
	complete_label.visible = state.phase == "complete"

func feedback(text: String, rejected: bool = false) -> void:
	message_label.text = text
	message_label.modulate = Color("f0b3a8") if rejected else Color.WHITE

func _hint() -> void:
	var hints := ["提示 1：两世界的道路不同。在断路前按空格。", "提示 2：里世界左上方的压力板会持续点亮，离开后门不会关。", "提示 3：从压力板原路回到中央路口，向右下走到底，再回表世界沿右上通道到出口。"]
	feedback(hints[mini(help_level, hints.size()-1)])
	help_level += 1
