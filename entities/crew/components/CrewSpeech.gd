class_name CrewSpeech extends Node

## Handles crew speech bubbles and communication
## Manages speech display, timing, and context-based messages

signal speech_started(text: String)
signal speech_finished()

# Speech constants
const RANDOM_PHRASES := [
	"Excuse me.",
	"Move, damn it!",
	"Why's this here?",
	"Ugh!",
	"*Yawn*",
]

# Speech state
var is_speaking: bool = false

# Component references
var crew_member: Node
var speech_label: Label
var speech_timer: Timer

func _ready() -> void:
	crew_member = get_parent() as CrewMember
	_ensure_speech_nodes()

func initialize() -> void:
	_ensure_speech_nodes()

func say(text: String, duration: float = 2.5) -> void:
	if is_speaking:
		return
		
	_ensure_speech_label()
	if not is_instance_valid(speech_label):
		return
	
	# Reset and show
	speech_label.text = text
	speech_label.visible = true
	speech_label.modulate.a = 0.0
	
	# Center horizontally above the crew after size updates
	await crew_member.get_tree().process_frame
	speech_label.position.x = -speech_label.size.x / 2.0
	
	# Fade in, wait, fade out
	var t := crew_member.create_tween()
	is_speaking = true
	speech_started.emit(text)
	
	t.tween_property(speech_label, "modulate:a", 1.0, 0.2)
	t.tween_interval(max(0.0, duration - 0.4))
	t.tween_property(speech_label, "modulate:a", 0.0, 0.2)
	t.finished.connect(func():
		speech_label.visible = false
		is_speaking = false
		speech_finished.emit()
	)

func say_collision_phrase(other_object) -> void:
	if is_speaking:
		return
		
	if other_object is CrewMember:
		if randi() % 2 == 0:
			say("Excuse me.", 2.5)
		else:
			say("Move, damn it!", 2.5)
	else:
		say("Why's this here?", 2.5)

func say_random_phrase() -> void:
	if is_speaking:
		return
		
	var idx = randi() % RANDOM_PHRASES.size()
	say(RANDOM_PHRASES[idx], 2.0)

func say_unreachable() -> void:
	say("That's outta reach, see?", 2.5)

func setup_random_speech_timer() -> void:
	_ensure_speech_timer()
	if is_instance_valid(speech_timer):
		speech_timer.wait_time = randf_range(6.0, 14.0)
		speech_timer.timeout.connect(_on_random_speech_timer_timeout)
		speech_timer.start()

func _on_random_speech_timer_timeout() -> void:
	# 50% chance to speak when timer fires
	if randi() % 2 == 0:
		say_random_phrase()
	_reset_speech_timer()

func _reset_speech_timer() -> void:
	_ensure_speech_timer()
	if is_instance_valid(speech_timer):
		speech_timer.wait_time = randf_range(6.0, 14.0)
		speech_timer.start()

func _ensure_speech_nodes() -> void:
	_ensure_speech_label()
	_ensure_speech_timer()

func _ensure_speech_label() -> void:
	if not is_instance_valid(speech_label):
		speech_label = crew_member.get_node_or_null("SpeechLabel")
		
	if not is_instance_valid(speech_label):
		var lbl := Label.new()
		lbl.name = "SpeechLabel"
		# Defer adding while parent tree is building to avoid blocked add_child()
		if crew_member.is_inside_tree() and crew_member.is_node_ready():
			crew_member.add_child(lbl)
			speech_label = lbl
		else:
			crew_member.call_deferred("add_child", lbl)
			speech_label = lbl
	
	# Configure size and placement
	speech_label.position = Vector2(0, -350)
	speech_label.z_index = 10
	speech_label.visible = false
	speech_label.modulate.a = 0.0
	speech_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speech_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speech_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var settings := LabelSettings.new()
	settings.font_size = 48
	speech_label.label_settings = settings

func _ensure_speech_timer() -> void:
	if is_instance_valid(speech_timer):
		return
		
	speech_timer = crew_member.get_node_or_null("SpeechTimer")
	if not is_instance_valid(speech_timer):
		var t := Timer.new()
		t.name = "SpeechTimer"
		t.one_shot = true
		t.autostart = false
		if crew_member.is_inside_tree() and crew_member.is_node_ready():
			crew_member.add_child(t)
		else:
			crew_member.call_deferred("add_child", t)
		speech_timer = t

# Public getters
func get_is_speaking() -> bool:
	return is_speaking
