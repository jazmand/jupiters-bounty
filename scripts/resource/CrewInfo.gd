class_name CrewInfo
extends Resource

var first_names: Array[String] = [
	"Judith",
	"Agatha",
	"Samantha",
	"Gemima",
	"Dorothy",
	"Aiko",
	"Noriko",
	"Setsuko",
	"Kiyoko",
	"Chiyoko",
]

var last_names: Array[String] = [
	"Gray",
	"Dalton",
	"Crawford",
	"Levine",
	"Cornwallis",
	"Yamagata",
	"Tachibana",
	"Matsumoto",
	"Ogawa",
	"Katagiri",
]

var id: int
var name: String
var age: int
var hometown: String

func _init() -> void:
	id = Global.station.crew.size() + 1
	name = generate_name()
	age = randi_range(18, 65)
	hometown = "New Ilion, Ganymede"
	

func generate_name() -> String:
	var first = first_names[randi_range(0, len(first_names) - 1)]
	var last = last_names[randi_range(0, len(last_names) - 1)]
	return "%s %s" % [first, last]
