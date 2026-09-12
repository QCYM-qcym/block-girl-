extends Node2D

signal move_requested(direction: Vector2i)
signal switch_requested
signal reset_requested
signal hint_requested
signal action_finished(action: String)

const SKINS = [preload("res://production/sprites/mutsumi_sprite_frames.tres"), preload("res://production/sprites/mortis_sprite_frames.tres")]
@onready var body: AnimatedSprite2D = $Body
@onready var shadow: AnimatedSprite2D = $Shadow
var action := ""
var move_from := Vector2.ZERO
var move_to := Vector2.ZERO
var elapsed := 0.0
var duration := 1.0 / 3.0

func _ready() -> void:
	body.animation_finished.connect(_finished)
	set_world(0)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var supported := [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT, KEY_SPACE, KEY_R, KEY_H]
	# Prefer keyboard position, with a logical fallback for remote/accessibility input.
	var key: int = event.physical_keycode if event.physical_keycode in supported else event.keycode
	match key:
		KEY_W, KEY_UP: move_requested.emit(Vector2i.UP)
		KEY_D, KEY_RIGHT: move_requested.emit(Vector2i.RIGHT)
		KEY_S, KEY_DOWN: move_requested.emit(Vector2i.DOWN)
		KEY_A, KEY_LEFT: move_requested.emit(Vector2i.LEFT)
		KEY_SPACE: switch_requested.emit()
		KEY_R: reset_requested.emit()
		KEY_H: hint_requested.emit()
		_: return
	get_viewport().set_input_as_handled()

func set_world(world: int) -> void:
	body.sprite_frames = SKINS[world]
	shadow.sprite_frames = SKINS[world]
	shadow.play("shadow")
	body.play("subtle_idle")

func roll(to: Vector2, direction: Vector2i) -> void:
	move_from = position
	move_to = to
	elapsed = 0.0
	var animation: String = {Vector2i.UP: "roll_backward", Vector2i.RIGHT: "roll_right", Vector2i.DOWN: "roll_forward", Vector2i.LEFT: "roll_left"}[direction]
	duration = 0.0
	for frame in body.sprite_frames.get_frame_count(animation):
		duration += body.sprite_frames.get_frame_duration(animation, frame) / body.sprite_frames.get_animation_speed(animation)
	play_action("moving", animation)

func play_action(kind: String, animation: String) -> void:
	action = kind
	body.play(animation)

func _process(delta: float) -> void:
	if action == "moving":
		elapsed += delta
		position = move_from.lerp(move_to, minf(elapsed / duration, 1.0)).round()

func _finished() -> void:
	if action.is_empty(): return
	var finished := action
	if finished == "moving": position = move_to
	action = ""
	body.play("subtle_idle")
	action_finished.emit(finished)

func reset_player(at: Vector2) -> void:
	# No await/tween callbacks survive Reset.
	action = ""
	body.stop()
	position = at
	move_from = at
	move_to = at
	elapsed = 0.0
	set_world(0)
