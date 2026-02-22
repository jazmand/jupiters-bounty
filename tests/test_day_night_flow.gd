extends SceneTree

## Integration tests for day-night-cycle: phase boundaries, bed use_state, vigour thresholds.
## Run with: godot -s tests/test_day_night_flow.gd

const GameTimeScript = preload("res://common/time/GameTime.gd")
const MINUTES_PER_DAY: int = 600
const CrewVigourScript = preload("res://entities/crew/components/CrewVigour.gd")

func _init() -> void:
	_run_tests()
	quit()

func _run_tests() -> void:
	_test_phase_boundaries()
	_test_bed_use_state()
	_test_vigour_thresholds()
	print("Day-night flow integration tests passed.")

func _test_phase_boundaries() -> void:
	# 10-hour day (600 min); default night [0, 300) = first 5 hours
	assert(GameTimeScript.is_minute_in_night_range(0, 0, 300, MINUTES_PER_DAY) == true, "minute 0 is night")
	assert(GameTimeScript.is_minute_in_night_range(299, 0, 300, MINUTES_PER_DAY) == true, "minute 299 is night")
	assert(GameTimeScript.is_minute_in_night_range(300, 0, 300, MINUTES_PER_DAY) == false, "minute 300 is day")
	assert(GameTimeScript.is_minute_in_night_range(599, 0, 300, MINUTES_PER_DAY) == false, "minute 599 is day")
	# Phase flip at boundary
	var night_299 := GameTimeScript.is_minute_in_night_range(299, 0, 300, MINUTES_PER_DAY)
	var day_300 := GameTimeScript.is_minute_in_night_range(300, 0, 300, MINUTES_PER_DAY)
	assert(night_299 != day_300, "phase flips at night_end boundary")

func _test_bed_use_state() -> void:
	var bed_type: Resource = load("res://assets/furniture_type/bed.tres") as Resource
	assert(bed_type != null, "bed.tres exists")
	assert(bed_type.has_method("get_use_state"), "FurnitureType has get_use_state")
	var use_state: StringName = bed_type.get_use_state()
	assert(use_state == &"rest/sleep", "bed use_state is rest/sleep (arrival triggers rest)")

func _test_vigour_thresholds() -> void:
	# Path-to-bed triggers when should_rest() (vigour == 0); rest-in-place same condition
	assert(CrewVigourScript.VIGOUR_LOW_THRESHOLD == 2, "VIGOUR_LOW_THRESHOLD is 2")
	assert(CrewVigourScript.MAX_VIGOUR == 10, "MAX_VIGOUR is 10")
	# CrewVigour.should_rest() is current_vigour == 0 (tested via instantiation)
	var parent := Node.new()
	var vigour: Node = CrewVigourScript.new()
	parent.add_child(vigour)
	get_root().add_child(parent)
	vigour.initialize(0)
	assert(vigour.should_rest() == true, "should_rest when vigour 0")
	vigour.initialize(1)
	assert(vigour.should_rest() == false, "should_rest false when vigour 1")
	vigour.initialize(CrewVigourScript.MAX_VIGOUR)
	assert(vigour.should_rest() == false, "should_rest false when vigour max")
	parent.queue_free()
