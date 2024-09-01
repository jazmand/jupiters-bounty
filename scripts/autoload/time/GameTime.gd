extends Timer

signal day
signal hour
signal minute
signal second

const time: TimeData = preload("res://scripts/autoload/time/resources/time.tres")

const SECONDS_PER_MINUTE = 60
const MINUTES_PER_HOUR = 60
const HOURS_PER_DAY = 10
const MINUTES_PER_DAY = MINUTES_PER_HOUR * HOURS_PER_DAY
const SECONDS_PER_DAY = SECONDS_PER_MINUTE * MINUTES_PER_DAY

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

func add_seconds(amount: int) -> void:
	time.seconds += amount
	if time.seconds >= SECONDS_PER_MINUTE:
		time.seconds -= SECONDS_PER_MINUTE
		add_minutes(1)
	second.emit()

func add_minutes(amount: int) -> void:
	time.minutes += amount
	if time.minutes >= MINUTES_PER_HOUR:
		time.minutes -= MINUTES_PER_HOUR
		add_hours(1)
	minute.emit()

func add_hours(amount: int) -> void:
	time.hours += amount
	if time.hours >= HOURS_PER_DAY:
		time.hours -= HOURS_PER_DAY
		add_days(1)
	hour.emit()

func add_days(amount: int) -> void:
	time.days += amount
	day.emit()
