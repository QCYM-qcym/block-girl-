extends Control
const KEYS=preload("res://production/ui/p01/tutorial_keys.png")
var text: String="":
	set(value):
		text=value; queue_redraw()
var entry:=0.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
func _process(delta: float) -> void:
	entry=minf(1,entry+delta/0.45); queue_redraw()
func reset() -> void:
	entry=0; queue_redraw()
func key_icon(x: float,y: float,index: int) -> void:
	draw_texture_rect_region(KEYS,Rect2(Vector2(x,y),Vector2(28,28)),Rect2(index*16,0,14,14),Color(1,1,1,entry))
func _draw() -> void:
	var x:=roundf(size.x/2)
	if text=="W A S D":
		key_icon(x-14,-26,0)
		for i in 3: key_icon(x-46+i*32,6,i+1)
	elif text=="Space":
		draw_texture_rect_region(KEYS,Rect2(x-44,0,88,28),Rect2(0,16,44,14),Color(1,1,1,entry))
	elif "Q / E" in text:
		key_icon(x-96,0,4); key_icon(x-62,0,5)
		draw_texture_rect_region(KEYS,Rect2(x+4,0,24,28),Rect2(48,16,12,14),Color(1,1,1,entry))
		draw_texture_rect_region(KEYS,Rect2(x+34,2,42,22),Rect2(63,17,21,11),Color(1,1,1,entry))
