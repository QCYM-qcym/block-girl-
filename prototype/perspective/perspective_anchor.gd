extends RefCounted
var id: String
var node: Vector2i
var direction: Vector2i
var elevation := 0
var platform := 0
var worlds: Array = [0,1]
func _init(unique_id: String, cell: Vector2i, outward: Vector2i, island: int) -> void:
	id=unique_id
	node=cell
	direction=outward
	platform=island
func position() -> Vector2: return Vector2(node)+Vector2(direction)*0.5
