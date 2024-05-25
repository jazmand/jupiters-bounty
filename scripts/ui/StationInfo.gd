class_name StationInfo
extends VBoxContainer

@onready var currency_label: Label = $Currency
@onready var crew_label: Label = $Crew
@onready var power_label: Label = $Power

func _ready() -> void:
	set_currency_label(Global.station.currency)
	set_crew_label(Global.station.crew)
	set_power_label(Global.station.power)
	Global.station.currency_updated.connect(set_currency_label)
	Global.station.crew_updated.connect(set_crew_label)
	Global.station.power_updated.connect(set_power_label)

func set_currency_label(currency: int) -> void:
	currency_label.text = "Currency: " + str(currency)

func set_crew_label(crew: int) -> void:
	crew_label.text = "Crew: " + str(crew)

func set_power_label(power: int) -> void:
	power_label.text = "Power: " + str(power)

