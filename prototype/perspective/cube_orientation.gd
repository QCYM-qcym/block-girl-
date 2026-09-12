extends RefCounted
## Integer columns of a proper rotation. Local +Z is the only physical face marker.
var right := Vector3i.RIGHT
var up := Vector3i.UP
var forward := Vector3i(0,0,1)

func quarter(vector: Vector3i, axis: Vector3i) -> Vector3i:
	var cross := Vector3i(axis.y*vector.z-axis.z*vector.y, axis.z*vector.x-axis.x*vector.z, axis.x*vector.y-axis.y*vector.x)
	return cross + axis * (axis.x*vector.x+axis.y*vector.y+axis.z*vector.z)

func roll(direction: Vector2i) -> void:
	if absi(direction.x)+absi(direction.y) != 1: return
	var axis := Vector3i(direction.y,0,-direction.x)
	right = quarter(right,axis)
	up = quarter(up,axis)
	forward = quarter(forward,axis)

func roll_north() -> void: roll(Vector2i.UP)
func roll_south() -> void: roll(Vector2i.DOWN)
func roll_east() -> void: roll(Vector2i.RIGHT)
func roll_west() -> void: roll(Vector2i.LEFT)
func face_direction() -> Vector3i: return forward
func key() -> String: return "%s|%s|%s" % [right,up,forward]
func as_basis() -> Basis: return Basis(Vector3(right),Vector3(up),Vector3(forward))
func copy():
	var result = get_script().new()
	result.right = right
	result.up = up
	result.forward = forward
	return result
func valid() -> bool:
	var basis := as_basis()
	return right.length_squared()==1 and up.length_squared()==1 and forward.length_squared()==1 and is_equal_approx(basis.determinant(),1.0) and Vector3(right).dot(Vector3(up))==0 and Vector3(right).dot(Vector3(forward))==0 and Vector3(up).dot(Vector3(forward))==0
