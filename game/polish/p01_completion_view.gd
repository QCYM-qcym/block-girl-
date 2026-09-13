extends ColorRect
var elapsed:=0.0
var title: Label
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	title=Label.new(); add_child(title)
	title.add_theme_font_size_override("font_size",30)
	title.add_theme_color_override("font_color",Color("d7e3d8"))
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter=Control.MOUSE_FILTER_IGNORE
	title.text="P-01\n《另一个世界》\n\n完成\n\n[R] 再次游玩"
	reset()
func tick(delta: float,complete: bool) -> void:
	visible=complete
	if not complete: return
	elapsed=minf(1.8,elapsed+delta)
	color=Color(0.05,0.08,0.1,0.6*smoothstep(0.4,1.5,elapsed))
	title.modulate.a=smoothstep(0.9,1.8,elapsed)
	title.size=size
func reset() -> void:
	elapsed=0; visible=false; color=Color(0.05,0.08,0.1,0)
	if title: title.modulate.a=0
