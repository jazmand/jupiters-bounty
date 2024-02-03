class_name Clock
extends Sprite2D

@onready var time: Label = $Time

const SECONDS_PER_HOUR: int = 3600
const SECONDS_PER_MINUTE: int = 60

func _ready() -> void:
	update(Global.station.time)
	StationEvent.time_updated.connect(update)

func update(in_game_time: int) -> void:
	var hours = int(in_game_time / SECONDS_PER_HOUR)
	var minutes = int((in_game_time % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE)
	time.text = format_time(hours, minutes)

func format_time(hours: int, minutes: int) -> String:
	return str(hours).pad_zeros(2) + ":" + str(minutes).pad_zeros(2)

