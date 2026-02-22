class_name Clock extends Sprite2D

@onready var time: Label = $Time

func _ready() -> void:
	update()
	GameTime.minute.connect(update)
	GameTime.phase_changed.connect(_on_phase_changed)

func _on_phase_changed() -> void:
	update()

func update() -> void:
	time.text = format_time(GameTime.get_hour(), GameTime.get_minute()) + "  " + _phase_display_name()

func _phase_display_name() -> String:
	var phase: StringName = GameTime.get_phase()
	if phase == &"night":
		return "Night"
	return "Day"

func format_time(hours: int, minutes: int) -> String:
	return str(hours).pad_zeros(2) + ":" + str(minutes).pad_zeros(2)
