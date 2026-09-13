extends Node2D
## Accepted sprite adapter. Persistent physical orientation stays in Movement.
## Art debt: current frames reset their visible face when landing.
const SKINS=[preload("res://production/sprites/mutsumi_sprite_frames.tres"),preload("res://production/sprites/mortis_sprite_frames.tres")]
const ROLLS=["roll_backward","roll_right","roll_forward","roll_left"]
var body:=AnimatedSprite2D.new()
var shadow:=AnimatedSprite2D.new()
var mover
var view
func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	for sprite in [shadow,body]:
		sprite.offset=Vector2(0,-9)
		add_child(sprite)
	shadow.modulate.a=0.35
func bind(player,perspective) -> void:
	mover=player
	view=perspective
func refresh() -> void:
	if body.sprite_frames!=SKINS[mover.world]:
		body.sprite_frames=SKINS[mover.world]
		shadow.sprite_frames=SKINS[mover.world]
		shadow.play("shadow")
	var animation: String="subtle_idle"
	if mover.moving:
		for i in 4:
			if view.world_direction(i)==mover.direction: animation=ROLLS[i]
	elif mover.phase=="shift": animation="world_switch_start"
	elif mover.phase=="complete": animation="puzzle_complete"
	if body.animation!=animation: body.play(animation)
	if mover.moving:
		body.pause()
		body.set_frame_and_progress(mini(5,int(mover.fraction*6)),0)
