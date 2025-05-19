extends Node

@onready var manager: GameManager = %GameManager
@onready var background: ColorRect = %Background

func _ready():
	GameTime.start()
	for i in range(4):
		var x = 3000 + (i * 100)
		var y = 2000 + (i * 100)
		manager.new_crew_member(Vector2(x, y))
