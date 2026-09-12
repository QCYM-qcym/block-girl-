extends Node2D
signal state_changed(value: String)
@export_enum("Surface", "Inner") var world: int = 0
@export var kind: String = ""
@onready var visual: AnimatedSprite2D = $Visual
var state: String = ""

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_state(initial_state())

func initial_state() -> String:
	return "idle"

func set_state(value: String) -> void:
	if not visual.sprite_frames.has_animation(value): return
	state = value
	visual.play(value)
	state_changed.emit(value)
