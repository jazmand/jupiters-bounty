# Room.gd

extends Resource

class_name Room

@export var id: int
@export var roomTypeId: int
@export var topLeft: Vector2i
@export var bottomRight: Vector2i

func _init(
	p_id: int = 0,
	p_roomTypeId: int = 0,
	p_topLeft: Vector2i = Vector2i(0, 0),
	p_bottomRight: Vector2i = Vector2i(0, 0)
):
	id = p_id
	roomTypeId = p_roomTypeId
	topLeft = p_topLeft
	bottomRight = p_bottomRight
