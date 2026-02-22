extends SceneTree

## Unit tests for GameTime phase logic (day-night boundaries).
## Run with: godot -s tests/test_game_time_phase.gd

const GameTimeScript = preload("res://common/time/GameTime.gd")
const MINUTES_PER_DAY: int = 600

func _init() -> void:
	_run_tests()
	quit()

func _run_tests() -> void:
	# Non-wrapped range [0, 300): night = first 5 hours
	assert(GameTimeScript.is_minute_in_night_range(0, 0, 300, MINUTES_PER_DAY) == true, "minute 0 in [0,300) should be night")
	assert(GameTimeScript.is_minute_in_night_range(299, 0, 300, MINUTES_PER_DAY) == true, "minute 299 in [0,300) should be night")
	assert(GameTimeScript.is_minute_in_night_range(300, 0, 300, MINUTES_PER_DAY) == false, "minute 300 not in [0,300) should be day")
	assert(GameTimeScript.is_minute_in_night_range(599, 0, 300, MINUTES_PER_DAY) == false, "minute 599 should be day")

	# Wrapped range [480, 120): night = 8h to 2h (480 min to 120 min)
	assert(GameTimeScript.is_minute_in_night_range(480, 480, 120, MINUTES_PER_DAY) == true, "minute 480 in wrapped night")
	assert(GameTimeScript.is_minute_in_night_range(599, 480, 120, MINUTES_PER_DAY) == true, "minute 599 in wrapped night")
	assert(GameTimeScript.is_minute_in_night_range(0, 480, 120, MINUTES_PER_DAY) == true, "minute 0 in wrapped night")
	assert(GameTimeScript.is_minute_in_night_range(119, 480, 120, MINUTES_PER_DAY) == true, "minute 119 in wrapped night")
	assert(GameTimeScript.is_minute_in_night_range(120, 480, 120, MINUTES_PER_DAY) == false, "minute 120 ends wrapped night")
	assert(GameTimeScript.is_minute_in_night_range(479, 480, 120, MINUTES_PER_DAY) == false, "minute 479 before wrapped night")

	# Edge: equal start and end means no night (empty range when start == end)
	assert(GameTimeScript.is_minute_in_night_range(100, 100, 100, MINUTES_PER_DAY) == false, "empty range [100,100)")

	# Phase flip at boundary: crossing minute 300 with [0, 300) should flip from night to day
	assert(GameTimeScript.is_minute_in_night_range(299, 0, 300, MINUTES_PER_DAY) != GameTimeScript.is_minute_in_night_range(300, 0, 300, MINUTES_PER_DAY), "phase should flip at boundary 299->300")

	print("GameTime phase tests passed.")
