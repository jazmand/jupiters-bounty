class_name Clock extends Sprite2D

@onready var time: Label = $Time

func _ready() -> void:
	update()
	GameTime.minute.connect(update)

func update() -> void:
	time.text = format_time(GameTime.get_hour(), GameTime.get_minute())

func format_time(hours: int, minutes: int) -> String:
	return str(hours).pad_zeros(2) + ":" + str(minutes).pad_zeros(2)
