extends "res://tests/gameplay/cube_orientation_visual_test.gd"
const Formal=preload("res://game/player/orientation_sprite_presenter.gd")
var reference
func _ready() -> void:
	cube.free()
	cube=Formal.new()
	super._ready()
	get_window().title="Formal Sprite Orientation · 若叶睦 / Mortis"
	axis_label.text="正式角色像素资源（左） · 同一姿态驱动的 X 对照（右）\n脸只在固定物理面；背面和底面没有脸是正确结果"
	for child in get_children():
		if child is Label and child.text.begins_with("CUBE ORIENTATION"):
			child.text="SPRITE ORIENTATION / 正式角色滚动验收"
	reference=Cube.new(); reference.bind(mover,view); add_child(reference)
	reference.scale=Vector2.ONE*5
	layout()
func layout() -> void:
	cube.scale=Vector2.ONE*8
	cube.position=Vector2(680,410)
	if reference!=null: reference.position=Vector2(1000,410)
func _process(delta: float) -> void:
	super._process(delta)
	if reference!=null: reference.refresh()
