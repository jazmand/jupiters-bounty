extends Timer

signal day
signal hour
signal minute
signal second

const time: TimeData = preload("res://common/time/time.tres")

const SECONDS_PER_MINUTE: int = 60
const MINUTES_PER_HOUR: int = 60
const HOURS_PER_DAY: int = 10
const MINUTES_PER_DAY: int = MINUTES_PER_HOUR * HOURS_PER_DAY
const SECONDS_PER_DAY: int = SECONDS_PER_MINUTE * MINUTES_PER_DAY

const REAL_SECONDS_PER_TICK: float = 0.25
const GAME_SECONDS_PER_TICK: int = 5

func _ready() -> void:
	wait_time = REAL_SECONDS_PER_TICK
	timeout.connect(add_seconds.bind(GAME_SECONDS_PER_TICK))

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

func add_minutes(amount: int) -> void:
	time.minutes = add_time(time.minutes, amount, MINUTES_PER_HOUR, add_hours)
	minute.emit()

func add_hours(amount: int) -> void:
	time.hours = add_time(time.hours, amount, HOURS_PER_DAY, add_days)
	hour.emit()

func add_days(amount: int) -> void:
	time.days += amount
	day.emit()
