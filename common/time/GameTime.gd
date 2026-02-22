extends Timer

signal day
signal hour
signal minute
signal second
signal phase_changed

const time: TimeData = preload("res://common/time/time.tres")

const SECONDS_PER_MINUTE: int = 60
const MINUTES_PER_HOUR: int = 60
const HOURS_PER_DAY: int = 10
const MINUTES_PER_DAY: int = MINUTES_PER_HOUR * HOURS_PER_DAY
const SECONDS_PER_DAY: int = SECONDS_PER_MINUTE * MINUTES_PER_DAY

const REAL_SECONDS_PER_TICK: float = 0.25
const GAME_SECONDS_PER_TICK: int = 5

## Night boundaries within the 10-hour day (minutes 0..MINUTES_PER_DAY-1).
## When night_start_minute <= night_end_minute: night when minute in [night_start_minute, night_end_minute).
## When night_start_minute > night_end_minute: night wraps (e.g. 480 to 120 = 8h to 2h).
@export var night_start_minute: int = 0
@export var night_end_minute: int = 300

var _was_night: bool = false

func _ready() -> void:
	wait_time = REAL_SECONDS_PER_TICK
	timeout.connect(add_seconds.bind(GAME_SECONDS_PER_TICK))
	_was_night = is_night()

func get_day() -> int:
	return time.days

func get_hour() -> int:
	return time.hours

func get_minute() -> int:
	return time.minutes

func current_time_in_minutes() -> int:
	return (time.hours * MINUTES_PER_HOUR) + time.minutes

func current_time_in_seconds() -> int:
	return (current_time_in_minutes() * SECONDS_PER_MINUTE) + time.seconds

func add_time(current: int, amount: int, unit_max: int, updater: Callable) -> int:
	var new_time: int = current + amount
	if new_time >= unit_max:
		new_time -= unit_max
		updater.call(1)
	return new_time

func add_seconds(amount: int) -> void:
	time.seconds = add_time(time.seconds, amount, SECONDS_PER_MINUTE, add_minutes)
	second.emit()
	_check_and_emit_phase_changed()

func add_minutes(amount: int) -> void:
	time.minutes = add_time(time.minutes, amount, MINUTES_PER_HOUR, add_hours)
	minute.emit()

func add_hours(amount: int) -> void:
	time.hours = add_time(time.hours, amount, HOURS_PER_DAY, add_days)
	hour.emit()

func add_days(amount: int) -> void:
	time.days += amount
	day.emit()

## Returns true when minute_of_day falls within the night range [night_start, night_end).
## Handles wrapped ranges: if night_start > night_end, night is [night_start, minutes_per_day) or [0, night_end).
## When night_start == night_end, no minutes are night (returns false).
static func is_minute_in_night_range(minute_of_day: int, night_start: int, night_end: int, minutes_per_day: int) -> bool:
	if night_start == night_end:
		return false
	if night_start < night_end:
		return minute_of_day >= night_start and minute_of_day < night_end
	else:
		return minute_of_day >= night_start or minute_of_day < night_end

func is_night() -> bool:
	return is_minute_in_night_range(current_time_in_minutes(), night_start_minute, night_end_minute, MINUTES_PER_DAY)

func get_phase() -> StringName:
	return &"night" if is_night() else &"day"

func _check_and_emit_phase_changed() -> void:
	var now_night: bool = is_night()
	if now_night != _was_night:
		phase_changed.emit()
		_was_night = now_night
