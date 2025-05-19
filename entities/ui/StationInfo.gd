class_name StationInfo extends VBoxContainer

@onready var currency_label: Label = $Currency
@onready var crew_label: Label = $Crew

func _ready() -> void:
	set_currency_label(Global.station.currency)
	set_crew_label(Global.station.crew.size())
	Global.station.currency_updated.connect(set_currency_label)
	Global.station.crew_updated.connect(set_crew_label)

func set_currency_label(currency: int) -> void:
	currency_label.text = "Currency: " + str(currency)

func set_crew_label(crew: int) -> void:
	crew_label.text = "Crew: " + str(crew)
