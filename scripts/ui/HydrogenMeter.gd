class_name HydrogenMeter extends Sprite2D

@onready var fluid: ProgressBar = $HydrogenMeterFluid

func _ready() -> void:
	# Animate hydrogen progress bar to initially start from 0
	fluid.value = 0
	fluid.max_value = Global.station.max_hydrogen
	update(Global.station.hydrogen)
	Global.station.hydrogen_updated.connect(update)
	Global.station.max_hydrogen_updated.connect(update_max_hydrogen)

func update(hydrogen: int) -> void:
	animate_progress_bar(fluid.value, hydrogen)
	fluid.value = hydrogen

func update_max_hydrogen(max_hydrogen: int) -> void:
	fluid.max_value = max_hydrogen

# Animate progress bar to increase or decrease. If required by other classes, extract to own class and extend.
func animate_progress_bar(from: float, to: float) -> void:
	var tween = get_tree().create_tween();
	tween.tween_property(fluid, "value", to, 2).set_trans(Tween.TRANS_LINEAR).from(from);
