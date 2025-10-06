class_name PumpData extends Resource

@export var id: int
@export var name: String = "Basic Pump"
@export var description: String = "A standard industrial pump for resource processing"
@export var model_type: int = 0  # 0=basic, 1a, 1b, 2a, 2b, 3
@export var efficiency_multiplier: float = 1.0
@export var maintenance_multiplier: float = 1.0
@export var power_consumption: int = 10
@export var upgrade_level: int = 0
@export var emits_pollution: bool = false
@export var emits_radiation: bool = false

# Raypunk model names
const MODEL_NAMES = {
	0: "Basic Pump",           # Default starting pump
	1: "Reliability Series",   # 1a & 1b - same output, better maintenance
	2: "Power Series",         # 2a & 2b - higher output, more maintenance
	3: "Quantum Series"        # 3 - highest output, radiation risk
}

const MODEL_VARIANTS = {
	"basic": "Le Cœur Standard",  # Basic pump (standard in French)
	"1a": "Le Cœur Fidèle 1",     # Same output, 75% maintenance (reliable)
	"1b": "Le Cœur Fidèle 2",     # 125% output, 50% maintenance (reliable)
	"2a": "Le Cœur Puissant 1",   # 150% output, 150% maintenance (powerful)
	"2b": "Le Cœur Puissant 2",   # 250% output, 200% maintenance + pollution (powerful)
	"3": "Atomic Force Pump"      # 200% output + radiation (external faction)
}

func _init(p_id: int = 0, p_model_type: int = 0):
	id = p_id
	model_type = p_model_type
	_set_model_properties()

func _set_model_properties():
	match model_type:
		0:  # Basic Pump
			name = MODEL_VARIANTS["basic"]
			efficiency_multiplier = 1.0
			maintenance_multiplier = 1.0
			power_consumption = 10
			emits_pollution = false
			emits_radiation = false
		1:  # Reliability Series (1a)
			name = MODEL_VARIANTS["1a"]
			efficiency_multiplier = 1.0
			maintenance_multiplier = 0.75
			power_consumption = 8
			emits_pollution = false
			emits_radiation = false
		2:  # Reliability Series (1b)
			name = MODEL_VARIANTS["1b"]
			efficiency_multiplier = 1.25
			maintenance_multiplier = 0.5
			power_consumption = 12
			emits_pollution = false
			emits_radiation = false
		3:  # Power Series (2a)
			name = MODEL_VARIANTS["2a"]
			efficiency_multiplier = 1.5
			maintenance_multiplier = 1.5
			power_consumption = 15
			emits_pollution = false
			emits_radiation = false
		4:  # Power Series (2b)
			name = MODEL_VARIANTS["2b"]
			efficiency_multiplier = 2.5
			maintenance_multiplier = 2.0
			power_consumption = 20
			emits_pollution = true
			emits_radiation = false
		5:  # American Atomic Series (3)
			name = MODEL_VARIANTS["3"]
			efficiency_multiplier = 2.0
			maintenance_multiplier = 1.0
			power_consumption = 25
			emits_pollution = false
			emits_radiation = true

func get_full_name() -> String:
	return name

func get_description() -> String:
	var desc = description + "\n"
	desc += "Output: " + str(int(efficiency_multiplier * 100)) + "%\n"
	desc += "Maintenance: " + str(int(maintenance_multiplier * 100)) + "%\n"
	desc += "Power: " + str(power_consumption) + "W"
	
	if emits_pollution:
		desc += "\n⚠️ Emits Pollution"
	if emits_radiation:
		desc += "\n☢️ Emits Radiation"
	
	return desc

