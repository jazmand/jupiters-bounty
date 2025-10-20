class_name Main extends Node

@onready var manager: GameManager = %GameManager
@onready var background: ColorRect = %Background

func _ready():
	GameTime.start()
