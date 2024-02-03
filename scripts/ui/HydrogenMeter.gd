class_name HydrogenMeter
extends Sprite2D

@onready var fluid: ProgressBar = $HydrogenMeterFluid

func _ready():
	# Animate hydrogen progress bar to initially start from 0
	fluid.value = 0
	update(Global.station.hydrogen)
	StationEvent.hydrogen_updated.connect(update)

func update(hydrogen: int) -> void:
	animate_progress_bar(fluid.value, hydrogen)
	fluid.value = hydrogen

# Animate progress bar to increase or decrease. If required by other classes, extract to own class and extend.
func animate_progress_bar(from: float, to: float) -> void:
	var tween = get_tree().create_tween();
	tween.tween_property(fluid, "value", to, 2).set_trans(Tween.TRANS_LINEAR).from(from);
